package tech.threefold.mycelium

import android.util.Log
import kotlinx.coroutines.*
import java.io.*
import java.net.*

/**
 * Simple utility to test if SOCKS5 proxy is working
 */
object SocksTest {
    private const val TAG = "SocksTest"
    
    fun testSocksProxy() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "Testing SOCKS5 proxy at 127.0.0.1:1080")
                
                val socket = Socket()
                socket.connect(InetSocketAddress("127.0.0.1", 1080), 5000)
                
                val input = socket.getInputStream()
                val output = socket.getOutputStream()
                
                // SOCKS5 handshake
                output.write(byteArrayOf(0x05, 0x01, 0x00))
                output.flush()
                
                val authResp = ByteArray(2)
                val n = input.read(authResp)
                
                if (n == 2 && authResp[0] == 0x05.toByte() && authResp[1] == 0x00.toByte()) {
                    Log.i(TAG, "✅ SOCKS5 proxy is working!")
                    
                    // Try to connect to a test server
                    val connectReq = byteArrayOf(
                        0x05, 0x01, 0x00, 0x03, // SOCKS5, CONNECT, reserved, domain name
                        0x0E, // Length of domain name (14)
                        *"www.google.com".toByteArray(),
                        0x00, 0x50 // Port 80
                    )
                    output.write(connectReq)
                    output.flush()
                    
                    val connectResp = ByteArray(10)
                    val respLen = input.read(connectResp)
                    
                    if (respLen >= 4 && connectResp[0] == 0x05.toByte() && connectResp[1] == 0x00.toByte()) {
                        Log.i(TAG, "✅ SOCKS5 proxy can connect to external hosts!")
                    } else {
                        Log.w(TAG, "⚠️ SOCKS5 proxy handshake OK but connection failed")
                    }
                } else {
                    Log.e(TAG, "❌ SOCKS5 proxy handshake failed")
                }
                
                socket.close()
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ SOCKS5 proxy test failed: ${e.message}")
                Log.e(TAG, "Make sure you've connected to a proxy node first!")
            }
        }
    }
}
