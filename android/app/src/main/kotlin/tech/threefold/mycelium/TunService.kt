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
        const val EVENT_INTENT = "tech.threefold.mycelium.TunService.EVENT"
        const val ACTION_START = "tech.threefold.mycelium.TunService.START"
        const val ACTION_STOP = "tech.threefold.mycelium.TunService.STOP"
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
        stop()
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
                stop()
                START_NOT_STICKY
            }
            ACTION_START -> {
                Log.i(tag, "[TunService]Starting...")
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
        Log.e(tag, "start to create the TUN device with node address:  $nodeAddress")

        val builder = Builder()
            .addAddress(nodeAddress, 64)
            .addRoute("400::", 7)
            .allowBypass()
            .allowFamily(OsConstants.AF_INET)
            //.allowFamily(OsConstants.AF_INET6)
            //.setBlocking(true)
            //.setMtu(1400)
            .setSession("mycelium")

        Log.i(tag, "Builder created")

        parcel = builder.establish()

        Log.i(tag, "Builder established")
        val parcel = parcel
        if (parcel == null || !parcel.fileDescriptor.valid()) {
            Log.e(tag, "Parcel was null or invalid")
            stop()
            return 0
        }

        Log.d(tag, "parcel fd: " + parcel.fd)
        Log.i(tag, "starting mycelium")
        launch {
            // TODO: detect if startMycelium failed and handle it
            // how?
            try {
                startMycelium(peers, parcel.fd, secretKey)
                if (started.get() == true) {
                    Log.e(tag, "mycelium unexpectedly finished")
                    sendBroadcast(Intent(EVENT_INTENT))
                } else {
                    Log.i(tag, "mycelium finished cleanly")
                }

            } catch (e: Exception) {
                Log.e(tag, "startMycelium failed with exception", e)
                // Handle the error here
            }
        }

        return parcel.fd
    }

    private fun stop() {
        Log.w(tag, "stop() called")

        if (!started.compareAndSet(true, false)) {
            Log.i(tag, "got stop when not started")
            return
        }

        val parcel = parcel ?: run {
            Log.e(tag, "Parcel was null, so stop() was not executed")
            return
        }
        stopMycelium()
        parcel.close()
        stopSelf()
    }
}