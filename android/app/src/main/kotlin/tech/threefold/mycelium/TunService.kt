package tech.threefold.mycelium

import android.content.Intent
import android.content.Context
import android.content.SharedPreferences
import android.net.VpnService
import android.net.ProxyInfo
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import tech.threefold.mycelium.rust.uniffi.mycelmob.addressFromSecretKey
import tech.threefold.mycelium.rust.uniffi.mycelmob.startMycelium
import tech.threefold.mycelium.rust.uniffi.mycelmob.stopMycelium
import kotlinx.coroutines.*
import kotlin.coroutines.CoroutineContext

private const val tag = "[TunService]"

class TunService : VpnService(), CoroutineScope {

    companion object {
        const val ACTION_START = "tech.threefold.mycelium.TunService.START"
        const val ACTION_STOP = "tech.threefold.mycelium.TunService.STOP"
        const val ACTION_QUERY = "tech.threefold.mycelium.TunService.QUERY"
        const val EVENT_INTENT = "tech.threefold.mycelium.TunService.EVENT"
        const val EVENT_MYCELIUM_FAILED = "mycelium_failed"
        const val EVENT_MYCELIUM_FINISHED = "mycelium_finished"
        const val EVENT_MYCELIUM_RUNNING = "mycelium_running"
    }

    private var started = AtomicBoolean()
    private var parcel: ParcelFileDescriptor? = null
    private var socksProxyEnabled = false
    private var httpProxy: LocalHttpProxy? = null
    private lateinit var prefs: SharedPreferences

    private val job = Job()

    override val coroutineContext: CoroutineContext
        get() = Dispatchers.IO + job

    override fun onCreate() {
        Log.d(tag, "tun service created")
        super.onCreate()
        prefs = getSharedPreferences("mycelium_prefs", Context.MODE_PRIVATE)
    }

    override fun onDestroy() {
        Log.e(tag, "onDestroy() tun service destroyed")
        stop(true)
        super.onDestroy()
        job.cancel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(tag, "Got a command " + intent!!.action)

        return when (intent.action ?: ACTION_STOP) {
            ACTION_STOP -> {
                // We initially call `stopSelf()` here, and put `stop()` in onDestroy().
                // But from the test, stopSelf() here won't call onDestroy().
                // But if we put stopSelf() on stop(), onDestroy() will be called, so we call stop() here
                // and call stopSelf() inside stop()
                stop(true)
                START_NOT_STICKY
            }
            ACTION_START -> {
                val secretKey = intent.getByteArrayExtra("secret_key") ?: ByteArray(0)
                val peers = intent.getStringArrayListExtra("peers") ?: emptyList()
                val socksEnabled = intent.getBooleanExtra("socks_enabled", false)
                start(peers.toList(), secretKey, socksEnabled)
                START_STICKY
            }
            ACTION_QUERY -> {
                if (started.get()) {
                    sendMyceliumEvent(EVENT_MYCELIUM_RUNNING)
                } else {
                    sendMyceliumEvent(EVENT_MYCELIUM_FINISHED)
                }
                START_NOT_STICKY
            }
            else -> {
                Log.e(tag, "unknown command")
                START_NOT_STICKY
            }
        }
    }


    private fun start(peers: List<String>, secretKey: ByteArray, socksEnabled: Boolean = false): Int {
        if (!started.compareAndSet(false, true)) {
            return 0
        }
        prefs.edit().putBoolean("mycelium_running", true).apply()
        val nodeAddress = addressFromSecretKey(secretKey)
        Log.i(tag, "creating TUN device with node address:  $nodeAddress")

        val builder = Builder()
            .addAddress(nodeAddress, 64)
            .addRoute("400::", 7)
            .addDnsServer("8.8.8.8")
            .addDnsServer("8.8.4.4")
            .addDnsServer("2001:4860:4860::8888")
            .addDnsServer("2001:4860:4860::8844")
            .allowFamily(OsConstants.AF_INET)
            .allowFamily(OsConstants.AF_INET6)
            .setMtu(1420)
            .setSession("mycelium")

        // Store SOCKS enabled state and configure proxy
        socksProxyEnabled = socksEnabled
        if (socksEnabled) {
            Log.i(tag, "🌐 Configuring VPN to use HTTP proxy at 127.0.0.1:8118")
            // Set HTTP proxy for all apps using this VPN
            builder.setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", 8118))
        }


        parcel = builder.establish()

        val parcel = parcel
        if (parcel == null || !parcel.fileDescriptor.valid()) {
            Log.e(tag, "Parcel was null or invalid")
            stop(false)
            sendMyceliumEvent(EVENT_MYCELIUM_FAILED)
            return 0
        }

        Log.d(tag, "starting mycelium with parcel fd: " + parcel.fd)
        
        // Start HTTP proxy if SOCKS enabled
        if (socksEnabled) {
            launch {
                delay(2000) // Wait for mycelium to start
                SocksTest.testSocksProxy()
                
                // Start local HTTP proxy
                httpProxy = LocalHttpProxy()
                httpProxy?.start()
                Log.i(tag, "✅ Proxy configured automatically - your traffic is now routed through the proxy!")
            }
        }
        
        launch {
            try {
                startMycelium(peers, parcel.fd, secretKey)
                if (started.get() == true) {
                    Log.e(tag, "mycelium unexpectedly finished")
                    stop(false)
                    sendMyceliumEvent(EVENT_MYCELIUM_FAILED)
                } else {
                    Log.i(tag, "mycelium finished cleanly")
                    stop(true)
                }

            } catch (e: Exception) {
                Log.e(tag, "startMycelium failed with exception", e)
                // Handle the error here
            }
        }

        return parcel.fd
    }

    private fun stop(stopMycelium: Boolean) {
        Log.d(tag, "stop() called")
        if (!started.compareAndSet(true, false)) {
            Log.d(tag, "got stop when not started")
            return
        }
        
        // Stop HTTP proxy
        httpProxy?.stop()
        httpProxy = null
        socksProxyEnabled = false
        
        prefs.edit().putBoolean("mycelium_running", false).apply()
        if (stopMycelium) {
            stopMycelium()
        }
        parcel?.close()
        stopSelf()
    }

    fun sendMyceliumEvent(event: String) {
        var intent = Intent(EVENT_INTENT)
        intent.putExtra("event", event)
        sendBroadcast(intent)
    }
}
