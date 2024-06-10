package tech.threefold.mycelium

import android.content.Intent
import android.net.VpnService
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
        const val EVENT_INTENT = "tech.threefold.mycelium.TunService.EVENT"
        const val EVENT_MYCELIUM_FAILED = "mycelium_failed"
        const val EVENT_MYCELIUM_FINISHED = "mycelium_finished"
    }

    private var started = AtomicBoolean()
    private var parcel: ParcelFileDescriptor? = null

    private val job = Job()

    override val coroutineContext: CoroutineContext
        get() = Dispatchers.IO + job

    override fun onCreate() {
        Log.d(tag, "tun service created")
        super.onCreate()
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
                start(peers.toList(), secretKey)
                START_STICKY
            }
            else -> {
                Log.e(tag, "unknown command")

            }
        }
    }


    private fun start(peers: List<String>, secretKey: ByteArray): Int {
        if (!started.compareAndSet(false, true)) {
            return 0
        }
        val nodeAddress = addressFromSecretKey(secretKey)
        Log.i(tag, "creating TUN device with node address:  $nodeAddress")

        val builder = Builder()
            .addAddress(nodeAddress, 64)
            .addRoute("400::", 7)
            .allowBypass()
            .allowFamily(OsConstants.AF_INET)
            //.allowFamily(OsConstants.AF_INET6)
            //.setBlocking(true)
            //.setMtu(1400)
            .setSession("mycelium")


        parcel = builder.establish()

        val parcel = parcel
        if (parcel == null || !parcel.fileDescriptor.valid()) {
            Log.e(tag, "Parcel was null or invalid")
            stop(false)
            sendMyceliumEvent(EVENT_MYCELIUM_FAILED)
            return 0
        }

        Log.d(tag, "starting mycelium with parcel fd: " + parcel.fd)
        launch {
            try {
                startMycelium(peers, parcel.fd, secretKey)
                if (started.get() == true) {
                    Log.e(tag, "mycelium unexpectedly finished")
                    stop(false)
                    sendMyceliumEvent(EVENT_MYCELIUM_FAILED)
                } else {
                    Log.i(tag, "mycelium finished cleanly")
                    sendMyceliumEvent(EVENT_MYCELIUM_FINISHED)
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