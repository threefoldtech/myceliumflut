package tech.threefold.mycelium

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import tech.threefold.mycelium.rust.uniffi.mycelmob.addressFromSecretKey
import tech.threefold.mycelium.rust.uniffi.mycelmob.generateSecretKey

private const val tag = "[Myceliumflut]"

class MainActivity: FlutterActivity() {
    private val channel = "tech.threefold.mycelium/tun"
    private val vpnRequestCode = 0x0F

    // these two variables are only used during VPN permission flow.
    private var vpnPermissionPeers: List<String>? = null
    private var vpnPermissionSecretKey: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
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
                    val peers = call.argument<List<String>>("peers")!!
                    val secretKey = call.argument<ByteArray>("secretKey")!!
                    Log.d("tff", "peers = $peers")
                    val started = startVpn(peers, secretKey)
                    result.success(started)
                }
                "stopVpn" -> {
                    val stopCmdSent = stopVpn()
                    Log.d("tff",  "stopping VPN")
                    result.success(stopCmdSent)
                }
                else -> result.notImplemented()
            }
        }
    }

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
        Log.d("tff", "preparing vpn service")

        if (checkAskVpnPermission(peers, secretKey) == true) {
            // need to ask for permission, so stop the flow here.
            // permission handler will be handled by onActivityResult function
            return false
        }

        val intent = Intent(this, TunService::class.java)
        intent.action = TunService.ACTION_START
        intent.putExtra("secret_key", secretKey)
        intent.putStringArrayListExtra("peers", ArrayList(peers))
        val startResult = startService(intent)

        Log.e("tff", "TunService start service result: " + startResult.toString())

        return true
    }

    private fun stopVpn(): Boolean {
        val intent = Intent(this, TunService::class.java)
        intent.action = TunService.ACTION_STOP
        startService(intent)

        return true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ... your initialization code here ...
        Log.e(tag, "onCreate")
    }

    override fun onStart() {
        super.onStart()
        Log.e(tag, "onStart")
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
