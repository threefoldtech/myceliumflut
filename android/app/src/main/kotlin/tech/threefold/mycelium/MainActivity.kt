package tech.threefold.mycelium

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import tech.threefold.mycelium.rust.uniffi.mycelmob.addressFromSecretKey
import tech.threefold.mycelium.rust.uniffi.mycelmob.generateSecretKey

private const val tag = "Myceliumflut"

class MainActivity: FlutterActivity() {
    private val channelName = "tech.threefold.mycelium/tun"
    private val vpnRequestCode = 0x0F

    // these two variables are only used during VPN permission flow.
    private var vpnPermissionPeers: List<String>? = null
    private var vpnPermissionSecretKey: ByteArray? = null

    private lateinit var channel : MethodChannel
    private lateinit var preferencesManager: PreferencesManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel.setMethodCallHandler {
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
                    val peers = call.argument<List<String>>("peers")!!
                    val secretKey = call.argument<ByteArray>("secretKey")!!
                    Log.d("tff", "peers = $peers")
                    val started = startVpn(peers, secretKey)
                    result.success(started)
                }
                "stopVpn" -> {
                    val stopCmdSent = stopVpn()
                    Log.d(tag,  "stopping VPN")
                    result.success(stopCmdSent)
                }
                else -> result.notImplemented()
            }
        }
    }

    // TunService EVENT receiver
    // it receives events from TunService and handles them accordingly.
    private val tunServiceEventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val event = intent.getStringExtra("event")
            when (event) {
                TunService.EVENT_MYCELIUM_FINISHED -> {
                    channel.invokeMethod("notifyMyceliumFinished","")
                }
                TunService.EVENT_MYCELIUM_FAILED -> {
                    channel.invokeMethod("notifyMyceliumFailed", "")
                }
                else -> Log.e(tag, "tunServiceEventReceiver: Unknown event: $event")
            }
        }
    }

    private val bootReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver received by MainActivity")
            if (intent?.action == BootReceiver.BOOT_EVENT) {
                // Send event to Flutter
                Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver BOOT_EVENT received by MainActivity")

                channel.invokeMethod("onBootCompleted", null)
            }
        }
    }

    // onActivityResult is called when the user grants or denies the VPN permission.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == vpnRequestCode) {
            if (resultCode == Activity.RESULT_OK) {
                Log.i(tag, "VPN permission granted by the user")
                startVpn(this.vpnPermissionPeers ?: emptyList(), this.vpnPermissionSecretKey ?: ByteArray(0))
            } else {
                // The user denied the VPN permission,
                // TODO: handle this case as needed
                Log.e(tag, "VPN permission was denied by the user")
            }
        }
    }
    // checkAskVpnPermission will return true if we need to ask for permission,
    // false otherwise.
    private fun checkAskVpnPermission(peers: List<String>, secretKey: ByteArray): Boolean{
        val intent = VpnService.prepare(this)
        if (intent != null) {
            this.vpnPermissionPeers = peers
            this.vpnPermissionSecretKey = secretKey
            startActivityForResult(intent, vpnRequestCode)
            return true
        } else {
            return false
        }
    }
    private fun startVpn(peers: List<String>, secretKey: ByteArray): Boolean {
        if (checkAskVpnPermission(peers, secretKey) == true) {
            // need to ask for permission, so stop the flow here.
            // permission handler will be handled by onActivityResult function
            return false
        }

        val intent = Intent(this, TunService::class.java)
        intent.action = TunService.ACTION_START
        intent.putExtra("secret_key", secretKey)
        intent.putStringArrayListExtra("peers", ArrayList(peers))

        preferencesManager.savePeers(peers)
        preferencesManager.saveSecretKey(secretKey)
        startService(intent)

        return true
    }

    private fun stopVpn(): Boolean {
        val intent = Intent(this, TunService::class.java)
        intent.action = TunService.ACTION_STOP
        startService(intent)

        return true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK MainActivity onCreate STARTED")
        super.onCreate(savedInstanceState)
        preferencesManager = PreferencesManager(this)

        // Log the intent information
        Log.e(tag, "Intent action: ${intent?.action}")
        Log.e(tag, "Intent extras: ${intent?.extras}")

        // Check if launched from boot receiver
        if (intent?.getBooleanExtra("from_boot_receiver", false) == true) {
            Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK Started from boot receiver")
        }

        // ... your initialization code here ...
        val callback = NetworkStateCallback(this)
        callback.register()

        // boot receiver filter
        Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK onCreate boot filter config")
        val bootFilter = IntentFilter(BootReceiver.BOOT_EVENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            registerReceiver(bootReceiver, bootFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(bootReceiver, bootFilter)
        }

        // Register the receiver
        val filter = IntentFilter(TunService.EVENT_INTENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // SDK 34
            registerReceiver(tunServiceEventReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(tunServiceEventReceiver, filter)
        }
        Log.e(tag, "onCreate")
    }

    override fun onStart() {
        super.onStart()
        Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK onStart")
        // Activity is becoming visible to the user.
        // Start animations, resume media playback, register listeners, etc.
    }


    override fun onStop() {
        super.onStop()
        Log.e(tag, "onStop")
        // Activity is no longer visible to the user.
        // Stop animations, pause media playback, unregister listeners, etc.
    }

    override fun onResume() {
        super.onResume()
        Log.e(tag, "onResume")
        // Activity is in the foreground and interacting with the user.
        // Resume tasks that were paused in onPause(), refresh UI data, etc.
    }

    override fun onPause() {
        super.onPause()
        Log.e(tag, "onPause")
        // Activity is partially obscured or losing focus.
        // Pause tasks that shouldn't run in the background, release resources, etc.
    }

    override fun onDestroy() {
        Log.e(tag, "onDestroy")

        Log.i(tag, "onDestroy:Stopping VPN service")
        stopVpn()

        super.onDestroy()

        // Activity is about to be destroyed.
        // Clean up resources (e.g., close database connections, release network resources).
        // Unregister the receiver
        unregisterReceiver(tunServiceEventReceiver)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        Log.e(tag, "onSaveInstance")
        // Save UI state changes to the outState bundle.
    }

    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        Log.e(tag, "onRestoreInstance")
        // Restore UI state from the savedInstanceState bundle.

    }
}