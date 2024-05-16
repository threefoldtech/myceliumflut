package tech.threefold.mycelium

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import androidx.localbroadcastmanager.content.LocalBroadcastManager


class TunService : VpnService() {

    companion object {
        const val RECEIVER_INTENT = "tech.threefold.mycelium.TunService.MESSAGE"
        const val ACTION_START = "tech.threefold.mycelium.TunService.START"
        const val ACTION_STOP = "tech.threefold.mycelium.TunService.STOP"
    }

    private var started = AtomicBoolean()
    private var parcel: ParcelFileDescriptor? = null
    override fun onCreate() {
        Log.d("tff", "tun service created")
        super.onCreate()
    }

    override fun onDestroy() {
        super.onDestroy()
        stop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.e("tff", "Got a command " + intent!!.action)

        if (intent == null) {
            Log.d("TunService", "Intent is null")
            return START_NOT_STICKY
        }
        return when (intent.action ?: ACTION_STOP) {
            ACTION_STOP -> {
                Log.d("TunService", "Stopping...")
                stop(); START_NOT_STICKY
            }

            else -> {
                Log.e("tff", "[TunService]Starting...")
                val nodeAddr = intent.getStringExtra("node_addr") ?: "192.168.1.1"
                start(nodeAddr);
                START_STICKY
            }
        }
    }

    private fun start(nodeAddr: String): Int {
        if (!started.compareAndSet(false, true)) {
            return 0
        }
        Log.e("tff", "start to create the TUN device with node addr:" + nodeAddr)

        val builder = Builder()
            .addAddress(nodeAddr, 64)
            .addRoute("400::", 7)
            .allowBypass()
            .allowFamily(OsConstants.AF_INET)
            //.allowFamily(OsConstants.AF_INET6)
            //.setBlocking(true)
            //.setMtu(1400)
            .setSession("mycelium")

        Log.e("tff", "Builder created")

        parcel = builder.establish()

        Log.e("tff", "Builder established")
        val parcel = parcel
        if (parcel == null || !parcel.fileDescriptor.valid()) {
            stop()
            return 0
        }

        Log.e("tff", "#########   parcel fd: " + parcel.fd)

        // broadcast the parcel fd
        val intent = Intent(RECEIVER_INTENT)
        intent.putExtra("type", "state")
        intent.putExtra("parcel_fd", parcel.fd)
        intent.putExtra("started", true)
        Log.d("TunService", "BROADCAST")
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)

        return parcel.fd
    }

    private fun stop() {
        if (!started.compareAndSet(true, false)) {
            return
        }
        Log.e("tff", "TunService stop called")
        // stop the device from the rust code
        // (already done from the flutter side)

        parcel?.close()
        stopSelf()
    }
}