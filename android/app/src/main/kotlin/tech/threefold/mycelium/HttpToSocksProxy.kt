package tech.threefold.mycelium

import android.util.Log
import kotlinx.coroutines.*
import java.io.*
import java.net.*
import java.nio.charset.StandardCharsets

/**
 * HTTP-to-SOCKS proxy server that accepts HTTP requests and forwards them through SOCKS5
 * This bridges Android's HTTP proxy support with mycelium's SOCKS5 proxy
 */
class HttpToSocksProxy {
    companion object {
        private const val TAG = "HttpToSocksProxy"
        private const val HTTP_PROXY_PORT = 8080
        private const val SOCKS_HOST = "127.0.0.1"
        private const val SOCKS_PORT = 1080
    }

    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private var proxyJob: Job? = null

    /**
     * Start the HTTP-to-SOCKS proxy server
     */
    fun start() {
        if (isRunning) {
            Log.w(TAG, "HTTP-to-SOCKS proxy already running")
            return
        }

        isRunning = true
        Log.i(TAG, "Starting HTTP-to-SOCKS proxy on port $HTTP_PROXY_PORT")
        
        // Test if mycelium SOCKS proxy is running
        testSocksConnection()

        proxyJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                serverSocket = ServerSocket(HTTP_PROXY_PORT)
                Log.i(TAG, "HTTP-to-SOCKS proxy listening on port $HTTP_PROXY_PORT")

                while (isRunning) {
                    try {
                        val clientSocket = serverSocket?.accept()
                        if (clientSocket != null) {
                            Log.d(TAG, "New HTTP client connection from ${clientSocket.remoteSocketAddress}")
                            CoroutineScope(Dispatchers.IO).launch {
                                handleHttpClient(clientSocket)
                            }
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error accepting HTTP client: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "HTTP-to-SOCKS proxy server error: ${e.message}")
            }
        }
    }

    /**
     * Stop the HTTP-to-SOCKS proxy server
     */
    fun stop() {
        Log.i(TAG, "Stopping HTTP-to-SOCKS proxy")
        isRunning = false
        proxyJob?.cancel()
        
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing server socket: ${e.message}")
        }
        serverSocket = null
    }

    private suspend fun handleHttpClient(clientSocket: Socket) {
        try {
            val clientInput = BufferedReader(InputStreamReader(clientSocket.getInputStream()))
            val clientOutput = clientSocket.getOutputStream()

            // Read HTTP request
            val requestLine = clientInput.readLine()
            if (requestLine == null) {
                clientSocket.close()
                return
            }

            Log.d(TAG, "HTTP request: $requestLine")

            // Parse HTTP request
            val parts = requestLine.split(" ")
            if (parts.size < 3) {
                sendHttpError(clientOutput, "400 Bad Request")
                clientSocket.close()
                return
            }

            val method = parts[0]
            val url = parts[1]
            val httpVersion = parts[2]

            // Handle CONNECT method (HTTPS tunneling)
            if (method == "CONNECT") {
                handleHttpsConnect(url, clientInput, clientOutput, clientSocket)
            } else {
                // Handle regular HTTP requests
                handleHttpRequest(method, url, httpVersion, clientInput, clientOutput, clientSocket)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error handling HTTP client: ${e.message}")
        } finally {
            try {
                clientSocket.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing client socket: ${e.message}")
            }
        }
    }

    private suspend fun handleHttpsConnect(
        hostPort: String,
        clientInput: BufferedReader,
        clientOutput: OutputStream,
        clientSocket: Socket
    ) {
        try {
            // Parse host:port
            val parts = hostPort.split(":")
            val host = parts[0]
            val port = if (parts.size > 1) parts[1].toInt() else 443

            Log.d(TAG, "HTTPS CONNECT to $host:$port")

            // Connect through SOCKS proxy
            val socksSocket = connectThroughSocks(host, port)
            if (socksSocket == null) {
                sendHttpError(clientOutput, "502 Bad Gateway")
                return
            }

            // Send 200 Connection Established
            clientOutput.write("HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray())
            clientOutput.flush()

            // Start bidirectional forwarding
            val job1 = CoroutineScope(Dispatchers.IO).launch {
                forwardData(clientSocket.getInputStream(), socksSocket.getOutputStream(), "client->socks")
            }
            val job2 = CoroutineScope(Dispatchers.IO).launch {
                forwardData(socksSocket.getInputStream(), clientOutput, "socks->client")
            }

            // Wait for either direction to close
            try {
                job1.join()
            } catch (e: Exception) {
                // One direction closed, cancel the other
            }
            
            job1.cancel()
            job2.cancel()
            socksSocket.close()

        } catch (e: Exception) {
            Log.e(TAG, "Error in HTTPS CONNECT: ${e.message}")
        }
    }

    private suspend fun handleHttpRequest(
        method: String,
        url: String,
        httpVersion: String,
        clientInput: BufferedReader,
        clientOutput: OutputStream,
        clientSocket: Socket
    ) {
        try {
            // Parse URL to extract host and port
            val uri = URI(url)
            val host = uri.host ?: return
            val port = if (uri.port != -1) uri.port else 80

            Log.d(TAG, "HTTP $method to $host:$port")

            // Connect through SOCKS proxy
            val socksSocket = connectThroughSocks(host, port)
            if (socksSocket == null) {
                sendHttpError(clientOutput, "502 Bad Gateway")
                return
            }

            val socksOutput = socksSocket.getOutputStream()
            val socksInput = socksSocket.getInputStream()

            // Forward the original request
            socksOutput.write("$method ${uri.path}${if (uri.query != null) "?" + uri.query else ""} $httpVersion\r\n".toByteArray())

            // Forward headers
            var line: String?
            while (clientInput.readLine().also { line = it } != null && line!!.isNotEmpty()) {
                socksOutput.write("$line\r\n".toByteArray())
            }
            socksOutput.write("\r\n".toByteArray())
            socksOutput.flush()

            // Forward response back to client
            forwardData(socksInput, clientOutput, "socks->client")
            socksSocket.close()

        } catch (e: Exception) {
            Log.e(TAG, "Error in HTTP request: ${e.message}")
        }
    }

    private suspend fun connectThroughSocks(host: String, port: Int): Socket? {
        return withContext(Dispatchers.IO) {
            try {
                val socksSocket = Socket(SOCKS_HOST, SOCKS_PORT)
                socksSocket.soTimeout = 10000

                val input = socksSocket.getInputStream()
                val output = socksSocket.getOutputStream()

                // SOCKS5 handshake
                output.write(byteArrayOf(0x05, 0x01, 0x00)) // Version 5, 1 method, no auth
                output.flush()

                val authResponse = ByteArray(2)
                if (input.read(authResponse) != 2 || authResponse[0] != 0x05.toByte() || authResponse[1] != 0x00.toByte()) {
                    Log.e(TAG, "SOCKS auth failed")
                    socksSocket.close()
                    return@withContext null
                }

                // SOCKS5 connect request
                val hostBytes = host.toByteArray(StandardCharsets.UTF_8)
                val request = ByteArrayOutputStream()
                request.write(0x05) // Version
                request.write(0x01) // Connect command
                request.write(0x00) // Reserved
                request.write(0x03) // Domain name address type
                request.write(hostBytes.size) // Domain name length
                request.write(hostBytes) // Domain name
                request.write(port shr 8) // Port high byte
                request.write(port and 0xFF) // Port low byte

                output.write(request.toByteArray())
                output.flush()

                // Read connect response
                val response = ByteArray(10)
                val bytesRead = input.read(response)
                if (bytesRead < 4 || response[0] != 0x05.toByte() || response[1] != 0x00.toByte()) {
                    Log.e(TAG, "SOCKS connect failed")
                    socksSocket.close()
                    return@withContext null
                }

                Log.d(TAG, "Successfully connected to $host:$port through SOCKS")
                socksSocket
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect through SOCKS: ${e.message}")
                null
            }
        }
    }

    private suspend fun forwardData(input: InputStream, output: OutputStream, direction: String) {
        withContext(Dispatchers.IO) {
            try {
                val buffer = ByteArray(8192)
                while (true) {
                    val bytesRead = input.read(buffer)
                    if (bytesRead <= 0) break
                    output.write(buffer, 0, bytesRead)
                    output.flush()
                }
            } catch (e: Exception) {
                Log.d(TAG, "Data forwarding stopped ($direction): ${e.message}")
            }
        }
    }

    private fun sendHttpError(output: OutputStream, error: String) {
        try {
            val response = "HTTP/1.1 $error\r\nContent-Length: 0\r\n\r\n"
            output.write(response.toByteArray())
            output.flush()
        } catch (e: Exception) {
            Log.e(TAG, "Error sending HTTP error: ${e.message}")
        }
    }

    private fun testSocksConnection() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "Testing connection to mycelium SOCKS proxy at $SOCKS_HOST:$SOCKS_PORT")
                val testSocket = Socket()
                testSocket.connect(InetSocketAddress(SOCKS_HOST, SOCKS_PORT), 5000)
                testSocket.close()
                Log.i(TAG, "✅ Mycelium SOCKS proxy is reachable at $SOCKS_HOST:$SOCKS_PORT")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Cannot connect to mycelium SOCKS proxy at $SOCKS_HOST:$SOCKS_PORT: ${e.message}")
                Log.e(TAG, "Make sure mycelium is running and SOCKS proxy is enabled")
            }
        }
    }

    /**
     * Get the port number this proxy is listening on
     */
    fun getPort(): Int = HTTP_PROXY_PORT
}
