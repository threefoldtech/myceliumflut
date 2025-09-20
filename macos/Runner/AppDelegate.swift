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
            (call: FlutterMethodCall, result: FlutterResult) -> Void in
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
            case "startVpn":
                // macOS doesn't support VPN tunnel like iOS/Android
                result(false)
            case "stopVpn":
                result(true)
            case "getPeerStatus":
                do {
                    let peerStatus = getPeerStatus()
                    result(peerStatus)
                } catch {
                    result(FlutterError(code: "PEER_STATUS_ERROR", message: error.localizedDescription, details: nil))
                }
            case "proxyConnect":
                do {
                    let remote = call.arguments as? String ?? ""
                    let proxyResult = proxyConnect(remote: remote)
                    result(proxyResult)
                } catch {
                    result(FlutterError(code: "PROXY_CONNECT_ERROR", message: error.localizedDescription, details: nil))
                }
            case "proxyDisconnect":
                do {
                    let proxyResult = proxyDisconnect()
                    result(proxyResult)
                } catch {
                    result(FlutterError(code: "PROXY_DISCONNECT_ERROR", message: error.localizedDescription, details: nil))
                }
            case "startProxyProbe":
                do {
                    let proxyResult = startProxyProbe()
                    result(proxyResult)
                } catch {
                    result(FlutterError(code: "START_PROXY_PROBE_ERROR", message: error.localizedDescription, details: nil))
                }
            case "stopProxyProbe":
                do {
                    let proxyResult = stopProxyProbe()
                    result(proxyResult)
                } catch {
                    result(FlutterError(code: "STOP_PROXY_PROBE_ERROR", message: error.localizedDescription, details: nil))
                }
            case "listProxies":
                do {
                    let proxyResult = listProxies()
                    result(proxyResult)
                } catch {
                    result(FlutterError(code: "LIST_PROXIES_ERROR", message: error.localizedDescription, details: nil))
                }
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
}
