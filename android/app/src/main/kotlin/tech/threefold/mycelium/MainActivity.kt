package tech.threefold.mycelium

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channel = "tech.threefold.mycelium/tun"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler {
            // This method is invoked on the main thread.
                call, result ->
            if (call.method == "getBatteryLevel") {
                result.success(90)
            } else {
                result.notImplemented()
            }
        }
    }
}
