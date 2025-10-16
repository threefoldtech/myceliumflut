package tech.threefold.mycelium

import android.util.Log
import kotlinx.coroutines.*
import java.io.*
import java.net.*
import java.nio.ByteBuffer
import java.nio.channels.SocketChannel

/**
 * SOCKS5 client implementation for routing TUN traffic through local SOCKS proxy
 */
class SocksProxy {
    companion object {
        private const val TAG = "SocksProxy"
        private const val SOCKS_VERSION = 0x05.toByte()
        private const val SOCKS_CMD_CONNECT = 0x01.toByte()
        private const val SOCKS_ATYP_IPV4 = 0x01.toByte()
        private const val SOCKS_ATYP_IPV6 = 0x04.toByte()
        private const val SOCKS_RSV = 0x00.toByte()
        private const val SOCKS_AUTH_NONE = 0x00.toByte()
        private const val SOCKS_SUCCESS = 0x00.toByte()
    }

    /**
     * Establish SOCKS5 connection to target through local proxy
     */
    suspend fun connectThroughSocks(targetHost: String, targetPort: Int): Socket? {
        return withContext(Dispatchers.IO) {
            try {
                val socksSocket = Socket("127.0.0.1", 1080)
                socksSocket.soTimeout = 10000 // 10 second timeout
                
                val input = socksSocket.getInputStream()
                val output = socksSocket.getOutputStream()
                
                // Step 1: Authentication negotiation
                if (!performSocksHandshake(input, output)) {
                    Log.e(TAG, "SOCKS handshake failed")
                    socksSocket.close()
                    return@withContext null
                }
                
                // Step 2: Connection request
                if (!performSocksConnect(input, output, targetHost, targetPort)) {
                    Log.e(TAG, "SOCKS connect failed")
                    socksSocket.close()
                    return@withContext null
                }
                
                Log.d(TAG, "Successfully connected to $targetHost:$targetPort through SOCKS")
                socksSocket
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect through SOCKS: ${e.message}")
                null
            }
        }
    }
    
    private fun performSocksHandshake(input: InputStream, output: OutputStream): Boolean {
        try {
            // Send authentication methods
            val authRequest = byteArrayOf(
                SOCKS_VERSION,      // Version
                0x01,               // Number of methods
                SOCKS_AUTH_NONE     // No authentication
            )
            output.write(authRequest)
            output.flush()
            
            // Read server response
            val response = ByteArray(2)
            if (input.read(response) != 2) {
                Log.e(TAG, "Failed to read SOCKS auth response")
                return false
            }
            
            if (response[0] != SOCKS_VERSION || response[1] != SOCKS_AUTH_NONE) {
                Log.e(TAG, "SOCKS auth failed: version=${response[0]}, method=${response[1]}")
                return false
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "SOCKS handshake error: ${e.message}")
            return false
        }
    }
    
    private fun performSocksConnect(input: InputStream, output: OutputStream, host: String, port: Int): Boolean {
        try {
            val hostBytes = host.toByteArray()
            val hostAddress = InetAddress.getByName(host).address
            val request = byteArrayOf(
                SOCKS_VERSION,      // Version
                SOCKS_CMD_CONNECT,  // Command: CONNECT
                SOCKS_RSV,          // Reserved
                SOCKS_ATYP_IPV4,    // Address type: IPv4
                hostAddress[0],     // IP byte 1
                hostAddress[1],     // IP byte 2
                hostAddress[2],     // IP byte 3
                hostAddress[3],     // IP byte 4
                (port shr 8).toByte(),  // Port high byte
                (port and 0xFF).toByte() // Port low byte
            )
            
            output.write(request)
            output.flush()
            
            // Read response
            val response = ByteArray(10) // Max response size for IPv4
            val bytesRead = input.read(response)
            if (bytesRead < 4) {
                Log.e(TAG, "Invalid SOCKS connect response length: $bytesRead")
                return false
            }
            
            if (response[0] != SOCKS_VERSION || response[1] != SOCKS_SUCCESS) {
                Log.e(TAG, "SOCKS connect failed: version=${response[0]}, status=${response[1]}")
                return false
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "SOCKS connect error: ${e.message}")
            return false
        }
    }
}
