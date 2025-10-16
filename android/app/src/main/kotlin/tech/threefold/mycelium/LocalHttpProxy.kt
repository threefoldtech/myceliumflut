package tech.threefold.mycelium

import android.util.Log
import kotlinx.coroutines.*
import java.io.*
import java.net.*

/**
 * Simple HTTP proxy that forwards requests to SOCKS5 proxy
 * Listens on port 8118 and forwards to SOCKS5 on port 1080
 */
class LocalHttpProxy {
    companion object {
        private const val TAG = "LocalHttpProxy"
        private const val HTTP_PORT = 8118
        private const val SOCKS_HOST = "127.0.0.1"
        private const val SOCKS_PORT = 1080
    }

    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun start() {
        if (isRunning) {
            Log.w(TAG, "Already running")
            return
        }

        scope.launch {
            try {
                serverSocket = ServerSocket(HTTP_PORT, 50, InetAddress.getByName("127.0.0.1"))
                isRunning = true
                Log.i(TAG, "✅ HTTP proxy started on 127.0.0.1:$HTTP_PORT")
                Log.i(TAG, "Configure your browser to use HTTP proxy: 127.0.0.1:$HTTP_PORT")

                while (isRunning) {
                    try {
                        val client = serverSocket?.accept() ?: break
                        launch { handleClient(client) }
                    } catch (e: SocketException) {
                        if (isRunning) {
                            Log.e(TAG, "Accept error: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Server error: ${e.message}")
            }
        }
    }

    fun stop() {
        Log.i(TAG, "Stopping HTTP proxy")
        isRunning = false
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            // Ignore
        }
        scope.cancel()
    }

    private suspend fun handleClient(client: Socket) = withContext(Dispatchers.IO) {
        try {
            client.soTimeout = 30000
            val clientInput = BufferedReader(InputStreamReader(client.getInputStream()))
            val clientOutput = client.getOutputStream()

            // Read HTTP request line
            val requestLine = clientInput.readLine() ?: return@withContext
            Log.d(TAG, "Request: $requestLine")

            val parts = requestLine.split(" ")
            if (parts.size < 3) return@withContext

            val method = parts[0]
            val url = parts[1]

            if (method == "CONNECT") {
                // HTTPS CONNECT tunneling
                handleConnect(url, client, clientInput, clientOutput)
            } else {
                // Regular HTTP request
                handleHttp(requestLine, url, client, clientInput, clientOutput)
            }
        } catch (e: Exception) {
            Log.d(TAG, "Client error: ${e.message}")
        } finally {
            try {
                client.close()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    private suspend fun handleConnect(
        hostPort: String,
        client: Socket,
        clientInput: BufferedReader,
        clientOutput: OutputStream
    ) = withContext(Dispatchers.IO) {
        try {
            // Parse host:port
            val parts = hostPort.split(":")
            if (parts.size != 2) return@withContext

            val host = parts[0]
            val port = parts[1].toIntOrNull() ?: 443

            Log.d(TAG, "CONNECT to $host:$port via SOCKS")

            // Skip remaining headers
            while (true) {
                val line = clientInput.readLine()
                if (line.isNullOrEmpty()) break
            }

            // Connect to SOCKS proxy
            val socksSocket = connectViaSocks(host, port)
            if (socksSocket == null) {
                clientOutput.write("HTTP/1.1 502 Bad Gateway\r\n\r\n".toByteArray())
                return@withContext
            }

            // Send success response
            clientOutput.write("HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray())
            clientOutput.flush()

            // Bidirectional forwarding
            val job1 = launch {
                try {
                    client.getInputStream().copyTo(socksSocket.getOutputStream())
                } catch (e: Exception) {
                    // Connection closed
                }
            }

            val job2 = launch {
                try {
                    socksSocket.getInputStream().copyTo(client.getOutputStream())
                } catch (e: Exception) {
                    // Connection closed
                }
            }

            job1.join()
            job2.join()

            socksSocket.close()
        } catch (e: Exception) {
            Log.e(TAG, "CONNECT error: ${e.message}")
        }
    }

    private suspend fun handleHttp(
        requestLine: String,
        url: String,
        client: Socket,
        clientInput: BufferedReader,
        clientOutput: OutputStream
    ) = withContext(Dispatchers.IO) {
        try {
            // Parse URL
            val uri = URI(url)
            val host = uri.host ?: return@withContext
            val port = if (uri.port > 0) uri.port else 80

            Log.d(TAG, "HTTP request to $host:$port")

            // Read headers
            val headers = mutableListOf<String>()
            while (true) {
                val line = clientInput.readLine()
                if (line.isNullOrEmpty()) break
                headers.add(line)
            }

            // Connect via SOCKS
            val socksSocket = connectViaSocks(host, port)
            if (socksSocket == null) {
                clientOutput.write("HTTP/1.1 502 Bad Gateway\r\n\r\n".toByteArray())
                return@withContext
            }

            val socksOutput = socksSocket.getOutputStream()
            val socksInput = socksSocket.getInputStream()

            // Forward request
            socksOutput.write("$requestLine\r\n".toByteArray())
            headers.forEach { socksOutput.write("$it\r\n".toByteArray()) }
            socksOutput.write("\r\n".toByteArray())
            socksOutput.flush()

            // Forward response
            socksInput.copyTo(clientOutput)

            socksSocket.close()
        } catch (e: Exception) {
            Log.e(TAG, "HTTP error: ${e.message}")
        }
    }

    private fun connectViaSocks(host: String, port: Int): Socket? {
        try {
            val socket = Socket(SOCKS_HOST, SOCKS_PORT)
            socket.soTimeout = 30000

            val input = socket.getInputStream()
            val output = socket.getOutputStream()

            // SOCKS5 handshake
            output.write(byteArrayOf(0x05, 0x01, 0x00))
            output.flush()

            val authResp = ByteArray(2)
            if (input.read(authResp) != 2 || authResp[0] != 0x05.toByte()) {
                socket.close()
                return null
            }

            // SOCKS5 connect request (domain name)
            val hostBytes = host.toByteArray()
            val connectReq = ByteArrayOutputStream()
            connectReq.write(byteArrayOf(0x05, 0x01, 0x00, 0x03)) // SOCKS5, CONNECT, reserved, domain
            connectReq.write(hostBytes.size) // Domain length
            connectReq.write(hostBytes) // Domain
            connectReq.write((port shr 8) and 0xFF) // Port high byte
            connectReq.write(port and 0xFF) // Port low byte

            output.write(connectReq.toByteArray())
            output.flush()

            // Read connect response
            val connectResp = ByteArray(10)
            val respLen = input.read(connectResp)
            if (respLen < 4 || connectResp[0] != 0x05.toByte() || connectResp[1] != 0x00.toByte()) {
                Log.e(TAG, "SOCKS connect failed for $host:$port")
                socket.close()
                return null
            }

            Log.d(TAG, "✅ Connected to $host:$port via SOCKS")
            return socket

        } catch (e: Exception) {
            Log.e(TAG, "SOCKS connection error: ${e.message}")
            return null
        }
    }
}
