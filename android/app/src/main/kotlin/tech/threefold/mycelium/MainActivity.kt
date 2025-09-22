package tech.threefold.mycelium

import android.annotation.SuppressLint
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
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
import tech.threefold.mycelium.rust.uniffi.mycelmob.getPeerStatus
import tech.threefold.mycelium.rust.uniffi.mycelmob.proxyConnect
import tech.threefold.mycelium.rust.uniffi.mycelmob.proxyDisconnect
import tech.threefold.mycelium.rust.uniffi.mycelmob.startProxyProbe
import tech.threefold.mycelium.rust.uniffi.mycelmob.stopProxyProbe
import tech.threefold.mycelium.rust.uniffi.mycelmob.listProxies

private const val tag = "[Myceliumflut]"

class MainActivity: FlutterActivity() {
    private val channelName = "tech.threefold.mycelium/tun"
    private val vpnRequestCode = 0x0F

    // these variables are only used during VPN permission flow.
    private var vpnPermissionPeers: List<String>? = null
    private var vpnPermissionSecretKey: ByteArray? = null
    private var vpnPermissionSocksEnabled: Boolean = false

    private lateinit var channel : MethodChannel
    private lateinit var prefs: SharedPreferences

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prefs = getSharedPreferences("mycelium_prefs", MODE_PRIVATE)
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
                    val socksEnabled = call.argument<Boolean>("socksEnabled") ?: false
                    Log.d("tff", "peers = $peers, socksEnabled = $socksEnabled")
                    val started = startVpn(peers, secretKey, socksEnabled)
                    result.success(started)
                }
                "stopVpn" -> {
                    val stopCmdSent = stopVpn()
                    Log.d(tag,  "stopping VPN")
                    result.success(stopCmdSent)
                }
                "getPeerStatus" -> {
                    try {
                        val peerStatus = getPeerStatus()
                        result.success(peerStatus)
                    } catch (e: Exception) {
                        Log.e(tag, "Error getting peer status: ${e.message}")
                        result.error("PEER_STATUS_ERROR", e.message, null)
                    }
                }
                "proxyConnect" -> {
                    try {
                        val remote = call.argument<String>("remote") ?: ""
                        val proxyResult = proxyConnect(remote)
                        result.success(proxyResult)
                    } catch (e: Exception) {
                        Log.e(tag, "Error in proxyConnect: ${e.message}")
                        result.error("PROXY_CONNECT_ERROR", e.message, null)
                    }
                }
                "proxyDisconnect" -> {
                    try {
                        val proxyResult = proxyDisconnect()
                        result.success(proxyResult)
                    } catch (e: Exception) {
                        Log.e(tag, "Error in proxyDisconnect: ${e.message}")
                        result.error("PROXY_DISCONNECT_ERROR", e.message, null)
                    }
                }
                "startProxyProbe" -> {
                    try {
                        val proxyResult = startProxyProbe()
                        result.success(proxyResult)
                    } catch (e: Exception) {
                        Log.e(tag, "Error in startProxyProbe: ${e.message}")
                        result.error("START_PROXY_PROBE_ERROR", e.message, null)
                    }
                }
                "stopProxyProbe" -> {
                    try {
                        val proxyResult = stopProxyProbe()
                        result.success(proxyResult)
                    } catch (e: Exception) {
                        Log.e(tag, "Error in stopProxyProbe: ${e.message}")
                        result.error("STOP_PROXY_PROBE_ERROR", e.message, null)
                    }
                }
                "listProxies" -> {
                    try {
                        val proxyResult = listProxies()
                        result.success(proxyResult)
                    } catch (e: Exception) {
                        Log.e(tag, "Error in listProxies: ${e.message}")
                        result.error("LIST_PROXIES_ERROR", e.message, null)
                    }
                "queryStatus" -> {
                    // Immediately report last known state while also querying the service
                    val running = prefs.getBoolean("mycelium_running", false)
                    if (running) {
                        channel.invokeMethod("notifyMyceliumStarted","")
                    } else {
                        channel.invokeMethod("notifyMyceliumFinished","")
                    }
                    queryStatus()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // TunService EVENT receiver
    // it receives events from TunService and handles them accordingly.
    private val tunServiceEventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (val event = intent.getStringExtra("event")) {
                TunService.EVENT_MYCELIUM_FINISHED -> {
                    channel.invokeMethod("notifyMyceliumFinished","")
                }
                TunService.EVENT_MYCELIUM_RUNNING -> {
                    channel.invokeMethod("notifyMyceliumStarted", "")
                }
                TunService.EVENT_MYCELIUM_FAILED -> {
                    channel.invokeMethod("notifyMyceliumFailed", "")
                }
                else -> Log.e(tag, "tunServiceEventReceiver: Unknown event: $event")
            }
        }
    }

    // onActivityResult is called when the user grants or denies the VPN permission.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == vpnRequestCode) {
            if (resultCode == Activity.RESULT_OK) {
                Log.i(tag, "VPN permission granted by the user")
                startVpn(this.vpnPermissionPeers ?: emptyList(), this.vpnPermissionSecretKey ?: ByteArray(0), this.vpnPermissionSocksEnabled)
            } else {
                // The user denied the VPN permission,
                // TODO: handle this case as needed
                Log.e(tag, "VPN permission was denied by the user")
            }
        }
    }
    // checkAskVpnPermission will return true if we need to ask for permission,
    // false otherwise.
    private fun checkAskVpnPermission(peers: List<String>, secretKey: ByteArray, socksEnabled: Boolean): Boolean{
        val intent = VpnService.prepare(this)
        if (intent != null) {
            this.vpnPermissionPeers = peers
            this.vpnPermissionSecretKey = secretKey
            this.vpnPermissionSocksEnabled = socksEnabled
            startActivityForResult(intent, vpnRequestCode)
            return true
        } else {
            return false
        }
    }
    private fun startVpn(peers: List<String>, secretKey: ByteArray, socksEnabled: Boolean = false): Boolean {
        if (checkAskVpnPermission(peers, secretKey, socksEnabled)) {
            // need to ask for permission, so stop the flow here.
            // permission handler will be handled by onActivityResult function
            return false
        }

        val intent = Intent(this, TunService::class.java)
        intent.action = TunService.ACTION_START
        intent.putExtra("secret_key", secretKey)
        intent.putExtra("socks_enabled", socksEnabled)
        intent.putStringArrayListExtra("peers", ArrayList(peers))
        startService(intent)

        return true
    }

    private fun stopVpn(): Boolean {
        val intent = Intent(this, TunService::class.java)
        intent.action = TunService.ACTION_STOP
        startService(intent)

        return true
    }

    private fun queryStatus() {
        val intent = Intent(this, TunService::class.java)
        intent.action = TunService.ACTION_QUERY
        startService(intent)
    }

    @SuppressLint("UnspecifiedRegisterReceiverFlag", "WrongConstant")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ... your initialization code here ...
        val callback = NetworkStateCallback(this)
        callback.register()

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
