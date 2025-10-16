package tech.threefold.mycelium

import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.*
import java.io.*
import java.net.*
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap

/**
 * Simple TUN to SOCKS5 forwarder
 * Routes TCP traffic from TUN interface through local SOCKS5 proxy
 */
class Tun2Socks(private val tunFd: ParcelFileDescriptor) {
    companion object {
        private const val TAG = "Tun2Socks"
        private const val SOCKS_HOST = "127.0.0.1"
        private const val SOCKS_PORT = 1080
    }

    private var isRunning = false
    private var forwarderJob: Job? = null
    private val connections = ConcurrentHashMap<String, TcpConnection>()

    fun start() {
        if (isRunning) {
            Log.w(TAG, "Already running")
            return
        }

        isRunning = true
        Log.i(TAG, "🚀 Starting TUN to SOCKS5 forwarder")

        forwarderJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                val input = FileInputStream(tunFd.fileDescriptor)
                val output = FileOutputStream(tunFd.fileDescriptor)
                val buffer = ByteArray(32768)

                while (isRunning) {
                    try {
                        val n = input.read(buffer)
                        if (n > 0) {
                            handlePacket(buffer, n, output)
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error reading packet: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Forwarder error: ${e.message}")
            }
        }
    }

    fun stop() {
        Log.i(TAG, "Stopping TUN to SOCKS5 forwarder")
        isRunning = false
        forwarderJob?.cancel()
        
        connections.values.forEach { it.close() }
        connections.clear()
    }

    private suspend fun handlePacket(buffer: ByteArray, length: Int, output: FileOutputStream) {
        try {
            // Simple IPv4 TCP packet parsing
            if (length < 20) return
            
            val version = (buffer[0].toInt() shr 4) and 0xF
            if (version != 4) return // Only IPv4
            
            val protocol = buffer[9].toInt() and 0xFF
            if (protocol != 6) return // Only TCP
            
            val headerLen = (buffer[0].toInt() and 0xF) * 4
            if (length < headerLen + 20) return
            
            // Extract IPs and ports
            val srcIp = String.format("%d.%d.%d.%d",
                buffer[12].toInt() and 0xFF,
                buffer[13].toInt() and 0xFF,
                buffer[14].toInt() and 0xFF,
                buffer[15].toInt() and 0xFF)
            
            val dstIp = String.format("%d.%d.%d.%d",
                buffer[16].toInt() and 0xFF,
                buffer[17].toInt() and 0xFF,
                buffer[18].toInt() and 0xFF,
                buffer[19].toInt() and 0xFF)
            
            val srcPort = ((buffer[headerLen].toInt() and 0xFF) shl 8) or (buffer[headerLen + 1].toInt() and 0xFF)
            val dstPort = ((buffer[headerLen + 2].toInt() and 0xFF) shl 8) or (buffer[headerLen + 3].toInt() and 0xFF)
            
            val connKey = "$srcIp:$srcPort->$dstIp:$dstPort"
            
            // Get or create connection
            var conn = connections[connKey]
            if (conn == null) {
                conn = TcpConnection(srcIp, srcPort, dstIp, dstPort, output)
                connections[connKey] = conn
                
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        conn.connect()
                    } catch (e: Exception) {
                        Log.e(TAG, "Connection failed: ${e.message}")
                        connections.remove(connKey)
                    }
                }
            }
            
            // Extract and forward payload
            val tcpHeaderLen = ((buffer[headerLen + 12].toInt() and 0xFF) shr 4) * 4
            val payloadOffset = headerLen + tcpHeaderLen
            if (payloadOffset < length) {
                val payload = buffer.copyOfRange(payloadOffset, length)
                conn.send(payload)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Packet handling error: ${e.message}")
        }
    }

    inner class TcpConnection(
        private val srcIp: String,
        private val srcPort: Int,
        private val dstIp: String,
        private val dstPort: Int,
        private val tunOutput: FileOutputStream
    ) {
        private var socket: Socket? = null
        private var connected = false

        suspend fun connect() = withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Connecting to $dstIp:$dstPort via SOCKS")
                
                // Connect to SOCKS proxy
                socket = Socket(SOCKS_HOST, SOCKS_PORT)
                socket?.soTimeout = 30000
                
                val input = socket?.getInputStream()
                val output = socket?.getOutputStream()
                
                if (input == null || output == null) {
                    throw IOException("Failed to get socket streams")
                }
                
                // SOCKS5 handshake
                output.write(byteArrayOf(0x05, 0x01, 0x00))
                output.flush()
                
                val authResp = ByteArray(2)
                if (input.read(authResp) != 2 || authResp[0] != 0x05.toByte()) {
                    throw IOException("SOCKS auth failed")
                }
                
                // SOCKS5 connect request
                val dstIpBytes = dstIp.split(".").map { it.toInt().toByte() }.toByteArray()
                val connectReq = byteArrayOf(
                    0x05, 0x01, 0x00, 0x01,
                    dstIpBytes[0], dstIpBytes[1], dstIpBytes[2], dstIpBytes[3],
                    (dstPort shr 8).toByte(), (dstPort and 0xFF).toByte()
                )
                output.write(connectReq)
                output.flush()
                
                val connectResp = ByteArray(10)
                val respLen = input.read(connectResp)
                if (respLen < 4 || connectResp[0] != 0x05.toByte() || connectResp[1] != 0x00.toByte()) {
                    throw IOException("SOCKS connect failed")
                }
                
                connected = true
                Log.d(TAG, "Connected to $dstIp:$dstPort via SOCKS")
                
                // Start reading responses
                startReading(input)
                
            } catch (e: Exception) {
                Log.e(TAG, "SOCKS connection error: ${e.message}")
                close()
                throw e
            }
        }

        private fun startReading(input: InputStream) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val buffer = ByteArray(8192)
                    while (connected) {
                        val n = input.read(buffer)
                        if (n <= 0) break
                        
                        // Create response packet and write to TUN
                        val packet = createResponsePacket(buffer.copyOf(n))
                        tunOutput.write(packet)
                        tunOutput.flush()
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "Read error: ${e.message}")
                } finally {
                    close()
                }
            }
        }

        fun send(data: ByteArray) {
            if (!connected || socket == null) return
            
            try {
                socket?.getOutputStream()?.write(data)
                socket?.getOutputStream()?.flush()
            } catch (e: Exception) {
                Log.e(TAG, "Send error: ${e.message}")
                close()
            }
        }

        fun close() {
            connected = false
            try {
                socket?.close()
            } catch (e: Exception) {
                // Ignore
            }
        }

        private fun createResponsePacket(payload: ByteArray): ByteArray {
            // Create minimal TCP/IP response packet
            val ipHeader = ByteArray(20)
            val tcpHeader = ByteArray(20)
            
            // IP header
            ipHeader[0] = 0x45.toByte() // Version 4, header length 5
            val totalLen = 20 + 20 + payload.size
            ipHeader[2] = (totalLen shr 8).toByte()
            ipHeader[3] = (totalLen and 0xFF).toByte()
            ipHeader[9] = 6 // TCP protocol
            
            // Swap source and destination IPs
            val dstIpBytes = dstIp.split(".").map { it.toInt().toByte() }
            val srcIpBytes = srcIp.split(".").map { it.toInt().toByte() }
            
            ipHeader[12] = dstIpBytes[0]
            ipHeader[13] = dstIpBytes[1]
            ipHeader[14] = dstIpBytes[2]
            ipHeader[15] = dstIpBytes[3]
            
            ipHeader[16] = srcIpBytes[0]
            ipHeader[17] = srcIpBytes[1]
            ipHeader[18] = srcIpBytes[2]
            ipHeader[19] = srcIpBytes[3]
            
            // TCP header
            tcpHeader[0] = (dstPort shr 8).toByte()
            tcpHeader[1] = (dstPort and 0xFF).toByte()
            tcpHeader[2] = (srcPort shr 8).toByte()
            tcpHeader[3] = (srcPort and 0xFF).toByte()
            tcpHeader[12] = 0x50.toByte() // Header length
            tcpHeader[13] = 0x18.toByte() // PSH + ACK flags
            
            return ipHeader + tcpHeader + payload
        }
    }
}
