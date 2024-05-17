package tech.threefold.mycelium

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import tech.threefold.mycelium.TunService
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import tech.threefold.mycelium.rust.uniffi.mycelmob.addressFromSecretKey
import tech.threefold.mycelium.rust.uniffi.mycelmob.generateSecretKey

class MainActivity: FlutterActivity() {
    private val channel = "tech.threefold.mycelium/tun"
    private lateinit var context: Context
    private lateinit var activity: Activity


    private var tun_fd: Int = 0

    var VPN_REQUEST_CODE = 0x0F // const val?


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler {
            // This method is invoked on the main thread.
                call, result ->
            when (call.method) {
                "addressFromSecretKey" -> {
                    val secretKey = call.arguments as ByteArray
                    val address = addressFromSecretKey(secretKey)
                    result.success(address)
                }
                "generateSecretKey" -> {
                    val secretKey = generateSecretKey()
                    result.success(secretKey)
                }
                "startVpn" -> {
                    var nodeAddr = call.argument<String>("nodeAddr")!!
                    var peers = call.argument<List<String>>("peers")!!
                    Log.d("tff", "nodeAddr = $nodeAddr")
                    Log.d("tff", "peers = $peers")
                    val started = startVpn(call.argument<String>("nodeAddr")!!)
                    Log.d("tff", "" + "VPN Started ")
                    result.success(started)
                }
                "stopVpn" -> {
                    val stopCmdSent = stopVpn()
                    Log.d("tff",  "stopping VPN")
                    result.success(stopCmdSent)
                }
                "getTunFD" -> result.success(tun_fd)
                else -> result.notImplemented()
            }
        }
    }

    private fun startVpn(nodeAddr: String): Boolean {
        Log.d("tff", "preparing vpn service")

        val intent = VpnService.prepare(context)
        if (intent != null) {
            Log.d("tff", "Start activity for result... ")
            activity.startActivityForResult(intent, VPN_REQUEST_CODE)
            return false;
        }

        // TODO FIXME
        // LocalBroadcastManager is deprecated, fix with new API
        LocalBroadcastManager.getInstance(activity)
            .registerReceiver(receiver, IntentFilter(TunService.RECEIVER_INTENT))

        val intentTff = Intent(context, TunService::class.java)
        val TASK_CODE = 100
        val pi = activity.createPendingResult(TASK_CODE, intentTff, 0)
        intentTff.action = TunService.ACTION_START
        intentTff.putExtra("node_addr", nodeAddr)
        val startResult = activity.startService(intentTff)

        Log.e("tff", "start service result: " + startResult.toString())

        return true
    }

    private fun stopVpn(): Boolean {
        val intent = Intent(context, TunService::class.java)
        intent.action = TunService.ACTION_STOP
        activity.startService(intent)

        return true
    }

    private val receiver: BroadcastReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent) {

                when (intent.getStringExtra("type")) {
                    "state" -> {
                        Log.e(
                            "tff - broadcast",
                            "" + intent.getBooleanExtra("started", false).toString()
                        )
                        Log.e(
                            "tff - broadcast",
                            "" + intent.getIntExtra("parcel_fd", 0).toString()
                        )
                        tun_fd = intent.getIntExtra("parcel_fd", 0)
                    }
                }
            }
        }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ... your initialization code here ...
        context = this
        activity = this
        Log.e("MyceliumFlut", "onCreate")
    }

    override fun onStart() {
        super.onStart()
        Log.e("MyceliumFlut", "onStart")
        // Activity is becoming visible to the user.
        // Start animations, resume media playback, register listeners, etc.
    }


    override fun onStop() {
        super.onStop()
        Log.e("MyceliumFlut", "onStop")
        // Activity is no longer visible to the user.
        // Stop animations, pause media playback, unregister listeners, etc.
    }

    override fun onResume() {
        super.onResume()
        Log.e("MyceliumFlut", "onResume")
        // Activity is in the foreground and interacting with the user.
        // Resume tasks that were paused in onPause(), refresh UI data, etc.
    }

    override fun onPause() {
        super.onPause()
        Log.e("MyceliumFlut", "onPause")
        // Activity is partially obscured or losing focus.
        // Pause tasks that shouldn't run in the background, release resources, etc.
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.e("MyceliumFlut", "onDestroy")
        // Activity is about to be destroyed.
        // Clean up resources (e.g., close database connections, release network resources).
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        Log.e("MyceliumFlut", "onSaveInstance")
        // Save UI state changes to the outState bundle.
    }

    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        Log.e("MyceliumFlut", "onRestoreInstance")
        // Restore UI state from the savedInstanceState bundle.

    }
}
