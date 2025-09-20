package tech.threefold.mycelium

import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.*
import java.io.*
import java.net.*
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.ConcurrentHashMap

/**
 * TUN-to-SOCKS forwarder that intercepts packets from TUN interface
 * and routes them through the local SOCKS proxy
 */
class TunToSocksForwarder(private val tunFd: ParcelFileDescriptor) {
    companion object {
        private const val TAG = "TunToSocksForwarder"
        private const val MTU = 1500
        private const val TCP_PROTOCOL = 6
        private const val UDP_PROTOCOL = 17
    }

    private val socksProxy = SocksProxy()
    private val activeConnections = ConcurrentHashMap<String, Socket>()
    private var isRunning = false
    private var forwarderJob: Job? = null

    /**
     * Start the TUN-to-SOCKS forwarding process
     */
    fun start() {
        if (isRunning) {
            Log.w(TAG, "Forwarder already running")
            return
        }

        isRunning = true
        Log.i(TAG, "Starting TUN-to-SOCKS forwarder")

        forwarderJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                val tunInput = FileInputStream(tunFd.fileDescriptor)
                val tunOutput = FileOutputStream(tunFd.fileDescriptor)
                val buffer = ByteArray(MTU)

                Log.i(TAG, "TUN forwarder started, reading packets...")
                
                while (isRunning) {
                    try {
                        val bytesRead = tunInput.read(buffer)
                        if (bytesRead > 0) {
                            Log.d(TAG, "Read $bytesRead bytes from TUN interface")
                            processPacket(buffer, bytesRead, tunOutput)
                        } else if (bytesRead == 0) {
                            // No data available, small delay to prevent busy waiting
                            delay(10)
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error processing packet: ${e.message}")
                            delay(100) // Prevent rapid error loops
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "TUN forwarder error: ${e.message}")
            }
        }
    }

    /**
     * Stop the forwarder and close all connections
     */
    fun stop() {
        Log.i(TAG, "Stopping TUN-to-SOCKS forwarder")
        isRunning = false
        forwarderJob?.cancel()
        
        // Close all active connections
        activeConnections.values.forEach { socket ->
            try {
                socket.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing connection: ${e.message}")
            }
        }
        activeConnections.clear()
    }

    private suspend fun processPacket(buffer: ByteArray, length: Int, tunOutput: FileOutputStream) {
        try {
            val packet = parseIPPacket(buffer, length) ?: return
            
            // Only handle TCP for now (HTTP/HTTPS traffic)
            if (packet.protocol != TCP_PROTOCOL) {
                return
            }

            val connectionKey = "${packet.srcIP}:${packet.srcPort}->${packet.dstIP}:${packet.dstPort}"
            
            // Check if this is a new connection
            if (!activeConnections.containsKey(connectionKey)) {
                handleNewConnection(packet, connectionKey, tunOutput)
            } else {
                // Forward data for existing connection
                forwardData(packet, connectionKey, tunOutput)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing packet: ${e.message}")
        }
    }

    private suspend fun handleNewConnection(packet: IPPacket, connectionKey: String, tunOutput: FileOutputStream) {
        try {
            Log.d(TAG, "New connection: $connectionKey")
            
            // Connect through SOCKS proxy
            val socksSocket = socksProxy.connectThroughSocks(packet.dstIP, packet.dstPort)
            if (socksSocket == null) {
                Log.e(TAG, "Failed to establish SOCKS connection for $connectionKey")
                return
            }

            activeConnections[connectionKey] = socksSocket

            // Start forwarding data in both directions
            CoroutineScope(Dispatchers.IO).launch {
                forwardFromSocksToTun(socksSocket, packet, tunOutput, connectionKey)
            }

            // Forward the initial packet data
            if (packet.payload.isNotEmpty()) {
                socksSocket.getOutputStream().write(packet.payload)
                socksSocket.getOutputStream().flush()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error handling new connection: ${e.message}")
        }
    }

    private suspend fun forwardData(packet: IPPacket, connectionKey: String, tunOutput: FileOutputStream) {
        try {
            val socket = activeConnections[connectionKey] ?: return
            
            if (packet.payload.isNotEmpty()) {
                socket.getOutputStream().write(packet.payload)
                socket.getOutputStream().flush()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error forwarding data: ${e.message}")
            // Remove failed connection
            activeConnections.remove(connectionKey)?.close()
        }
    }

    private suspend fun forwardFromSocksToTun(
        socket: Socket, 
        originalPacket: IPPacket, 
        tunOutput: FileOutputStream,
        connectionKey: String
    ) {
        try {
            val input = socket.getInputStream()
            val buffer = ByteArray(MTU)

            while (isRunning && !socket.isClosed) {
                val bytesRead = input.read(buffer)
                if (bytesRead <= 0) break

                // Create response packet and write to TUN
                val responsePacket = createResponsePacket(
                    originalPacket, 
                    buffer.copyOf(bytesRead)
                )
                tunOutput.write(responsePacket)
                tunOutput.flush()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error forwarding from SOCKS to TUN: ${e.message}")
        } finally {
            activeConnections.remove(connectionKey)
            try {
                socket.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing socket: ${e.message}")
            }
        }
    }

    private fun parseIPPacket(buffer: ByteArray, length: Int): IPPacket? {
        try {
            if (length < 20) return null // Minimum IP header size

            val version = (buffer[0].toInt() shr 4) and 0xF
            if (version != 4) return null // Only IPv4 for now

            val headerLength = (buffer[0].toInt() and 0xF) * 4
            val protocol = buffer[9].toInt() and 0xFF

            // Extract source and destination IPs
            val srcIP = "${buffer[12].toUByte()}.${buffer[13].toUByte()}.${buffer[14].toUByte()}.${buffer[15].toUByte()}"
            val dstIP = "${buffer[16].toUByte()}.${buffer[17].toUByte()}.${buffer[18].toUByte()}.${buffer[19].toUByte()}"

            if (protocol != TCP_PROTOCOL) return null

            // Extract TCP ports
            val tcpHeaderOffset = headerLength
            if (length < tcpHeaderOffset + 4) return null

            val srcPort = ((buffer[tcpHeaderOffset].toInt() and 0xFF) shl 8) or (buffer[tcpHeaderOffset + 1].toInt() and 0xFF)
            val dstPort = ((buffer[tcpHeaderOffset + 2].toInt() and 0xFF) shl 8) or (buffer[tcpHeaderOffset + 3].toInt() and 0xFF)

            val tcpHeaderLength = ((buffer[tcpHeaderOffset + 12].toInt() and 0xFF) shr 4) * 4
            val payloadOffset = tcpHeaderOffset + tcpHeaderLength
            val payload = if (payloadOffset < length) {
                buffer.copyOfRange(payloadOffset, length)
            } else {
                byteArrayOf()
            }

            return IPPacket(srcIP, srcPort, dstIP, dstPort, protocol, payload)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing IP packet: ${e.message}")
            return null
        }
    }

    private fun createResponsePacket(originalPacket: IPPacket, payload: ByteArray): ByteArray {
        // Create a simple TCP response packet
        // This is a simplified implementation - in production you'd want proper TCP state management
        val ipHeader = ByteArray(20)
        val tcpHeader = ByteArray(20)
        
        // IP Header (simplified)
        ipHeader[0] = 0x45.toByte() // Version 4, Header length 5*4=20
        ipHeader[1] = 0x00.toByte() // Type of service
        val totalLength = 20 + 20 + payload.size
        ipHeader[2] = (totalLength shr 8).toByte()
        ipHeader[3] = (totalLength and 0xFF).toByte()
        ipHeader[9] = TCP_PROTOCOL.toByte()
        
        // Source IP (swap with destination)
        val dstIPParts = originalPacket.dstIP.split(".")
        ipHeader[12] = dstIPParts[0].toInt().toByte()
        ipHeader[13] = dstIPParts[1].toInt().toByte()
        ipHeader[14] = dstIPParts[2].toInt().toByte()
        ipHeader[15] = dstIPParts[3].toInt().toByte()
        
        // Destination IP (swap with source)
        val srcIPParts = originalPacket.srcIP.split(".")
        ipHeader[16] = srcIPParts[0].toInt().toByte()
        ipHeader[17] = srcIPParts[1].toInt().toByte()
        ipHeader[18] = srcIPParts[2].toInt().toByte()
        ipHeader[19] = srcIPParts[3].toInt().toByte()
        
        // TCP Header (simplified)
        tcpHeader[0] = (originalPacket.dstPort shr 8).toByte()
        tcpHeader[1] = (originalPacket.dstPort and 0xFF).toByte()
        tcpHeader[2] = (originalPacket.srcPort shr 8).toByte()
        tcpHeader[3] = (originalPacket.srcPort and 0xFF).toByte()
        tcpHeader[12] = 0x50.toByte() // Header length 5*4=20
        tcpHeader[13] = 0x18.toByte() // PSH + ACK flags
        
        return ipHeader + tcpHeader + payload
    }

    data class IPPacket(
        val srcIP: String,
        val srcPort: Int,
        val dstIP: String,
        val dstPort: Int,
        val protocol: Int,
        val payload: ByteArray
    )
}
