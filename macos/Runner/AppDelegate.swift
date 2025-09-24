import Cocoa
import FlutterMacOS
import flutter_desktop_sleep

@main
class AppDelegate: FlutterAppDelegate {
    var _windowManager = FlutterDesktopSleepPlugin()
    private var flutterChannel: FlutterMethodChannel?
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        super.applicationDidFinishLaunching(notification)
        
        let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        flutterChannel = FlutterMethodChannel(name: "tech.threefold.mycelium/tun",
                                              binaryMessenger: controller.engine.binaryMessenger)
        flutterChannel!.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "generateSecretKey":
                let key = generateSecretKey()
                result(key)
            case "addressFromSecretKey":
                if let key = call.arguments as? FlutterStandardTypedData {
                    let nodeAddr = addressFromSecretKey(data: key.data)
                    result(nodeAddr)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Expect secret key", details: nil))
                }
            case "getPeerStatus":
                self.getPeerStatusFromService(result: result)
            case "proxyConnect":
                result(FlutterError(code: "NOT_IMPLEMENTED", message: "Proxy methods not yet available on macOS", details: nil))
            case "proxyDisconnect":
                result(FlutterError(code: "NOT_IMPLEMENTED", message: "Proxy methods not yet available on macOS", details: nil))
            case "startProxyProbe":
                result(FlutterError(code: "NOT_IMPLEMENTED", message: "Proxy methods not yet available on macOS", details: nil))
            case "stopProxyProbe":
                result(FlutterError(code: "NOT_IMPLEMENTED", message: "Proxy methods not yet available on macOS", details: nil))
            case "listProxies":
                result(FlutterError(code: "NOT_IMPLEMENTED", message: "Proxy methods not yet available on macOS", details: nil))
            default:
                result(FlutterMethodNotImplemented)
            }
        })
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        return _windowManager.applicationShouldTerminate(controller);
    }
    
    // MARK: - Mycelium Service Methods
    
    private func getPeerStatusFromService(result: @escaping FlutterResult) {
        // Run peer status check in background to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                let peerStatus = getPeerStatus()
                DispatchQueue.main.async {
                    print("macOS: Got peer status: \(peerStatus)")
                    result(peerStatus)
                }
            } catch {
                DispatchQueue.main.async {
                    print("macOS: Error getting peer status: \(error)")
                    result(FlutterError(code: "PEER_STATUS_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
}