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



private const val tag = "[TunService]"

class TunService : VpnService() {

    companion object {
        const val RECEIVER_INTENT = "tech.threefold.mycelium.TunService.MESSAGE"
        const val ACTION_START = "tech.threefold.mycelium.TunService.START"
        const val ACTION_STOP = "tech.threefold.mycelium.TunService.STOP"
    }

    private var started = AtomicBoolean()
    private var parcel: ParcelFileDescriptor? = null
    override fun onCreate() {
        Log.d(tag, "tun service created")
        super.onCreate()
    }

    override fun onDestroy() {
        super.onDestroy()
        stop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.e(tag, "Got a command " + intent!!.action)

        if (intent == null) {
            Log.d(tag, "Intent is null")
            return START_NOT_STICKY
        }
        return when (intent.action ?: ACTION_STOP) {
            ACTION_STOP -> {
                Log.d(tag, "Stopping...")
                stop(); START_NOT_STICKY
            }
            ACTION_START -> {
                Log.e(tag, "[TunService]Starting...")
                val nodeAddr = intent.getStringExtra("node_addr") ?: "192.168.1.1"
                val secretKey = intent.getByteArrayExtra("secret_key") ?: ByteArray(0)
                val peers = intent.getStringArrayListExtra("peers") ?: emptyList()
                start(peers.toList(), secretKey);
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
        val nodeAddr = addressFromSecretKey(secretKey)
        Log.e(tag, "start to create the TUN device with node addr:" + nodeAddr)

        val builder = Builder()
            .addAddress(nodeAddr, 64)
            .addRoute("400::", 7)
            .allowBypass()
            .allowFamily(OsConstants.AF_INET)
            //.allowFamily(OsConstants.AF_INET6)
            //.setBlocking(true)
            //.setMtu(1400)
            .setSession("mycelium")

        Log.e(tag, "Builder created")

        parcel = builder.establish()

        Log.e(tag, "Builder established")
        val parcel = parcel
        if (parcel == null || !parcel.fileDescriptor.valid()) {
            stop()
            return 0
        }

        Log.d(tag, "parcel fd: " + parcel.fd)
        Log.i(tag, "starting mycelium")
        GlobalScope.launch(Dispatchers.IO) {
            // TODO: detect if startMycelium failed and handle it
            // how?
            startMycelium(peers, parcel.fd, secretKey)
        }

        return parcel.fd
    }

    private fun stop() {
        Log.e(tag, "Stop called")

        if (!started.compareAndSet(true, false)) {
            return
        }

        val parcel = parcel
        if (parcel == null) {
            return
        }
        stopMycelium()
        parcel.close()
        stopSelf()
    }
}