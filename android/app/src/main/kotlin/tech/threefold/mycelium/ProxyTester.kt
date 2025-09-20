package tech.threefold.mycelium

import android.util.Log
import kotlinx.coroutines.*
import java.io.*
import java.net.*

/**
 * Simple utility to test proxy connections and debug routing issues
 */
class ProxyTester {
    companion object {
        private const val TAG = "ProxyTester"
    }

    /**
     * Test if we can connect to the mycelium SOCKS proxy
     */
    fun testSocksProxy() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "Testing SOCKS proxy connection to 127.0.0.1:1080")
                val socket = Socket()
                socket.connect(InetSocketAddress("127.0.0.1", 1080), 5000)
                
                // Try SOCKS5 handshake
                val output = socket.getOutputStream()
                val input = socket.getInputStream()
                
                // Send SOCKS5 greeting
                output.write(byteArrayOf(0x05, 0x01, 0x00)) // Version 5, 1 method, no auth
                output.flush()
                
                // Read response
                val response = ByteArray(2)
                val bytesRead = input.read(response)
                
                if (bytesRead == 2 && response[0] == 0x05.toByte() && response[1] == 0x00.toByte()) {
                    Log.i(TAG, "✅ SOCKS proxy is working correctly")
                } else {
                    Log.e(TAG, "❌ SOCKS proxy handshake failed: ${response.contentToString()}")
                }
                
                socket.close()
            } catch (e: Exception) {
                Log.e(TAG, "❌ SOCKS proxy test failed: ${e.message}")
            }
        }
    }

    /**
     * Test HTTP request through our HTTP-to-SOCKS bridge
     */
    fun testHttpProxy() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "Testing HTTP proxy connection to 127.0.0.1:8080")
                val socket = Socket()
                socket.connect(InetSocketAddress("127.0.0.1", 8080), 5000)
                
                val output = socket.getOutputStream()
                val input = BufferedReader(InputStreamReader(socket.getInputStream()))
                
                // Send simple HTTP request
                val request = "GET http://httpbin.org/ip HTTP/1.1\r\n" +
                        "Host: httpbin.org\r\n" +
                        "Connection: close\r\n\r\n"
                
                output.write(request.toByteArray())
                output.flush()
                
                // Read response
                val response = StringBuilder()
                var line: String?
                while (input.readLine().also { line = it } != null) {
                    response.append(line).append("\n")
                    if (response.length > 1000) break // Limit response size
                }
                
                Log.i(TAG, "HTTP proxy response: $response")
                socket.close()
            } catch (e: Exception) {
                Log.e(TAG, "❌ HTTP proxy test failed: ${e.message}")
            }
        }
    }

    /**
     * Test direct connection to check what IP we're actually using
     */
    fun testDirectConnection() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "Testing direct connection to httpbin.org")
                val socket = Socket()
                socket.connect(InetSocketAddress("httpbin.org", 80), 10000)
                
                val output = socket.getOutputStream()
                val input = BufferedReader(InputStreamReader(socket.getInputStream()))
                
                val request = "GET /ip HTTP/1.1\r\n" +
                        "Host: httpbin.org\r\n" +
                        "Connection: close\r\n\r\n"
                
                output.write(request.toByteArray())
                output.flush()
                
                val response = StringBuilder()
                var line: String?
                while (input.readLine().also { line = it } != null) {
                    response.append(line).append("\n")
                    if (response.length > 1000) break
                }
                
                Log.i(TAG, "Direct connection response: $response")
                socket.close()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Direct connection test failed: ${e.message}")
            }
        }
    }
}
