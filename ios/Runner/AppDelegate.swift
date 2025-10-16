import UIKit
import Flutter
import NetworkExtension
import Foundation
import OSLog

@main
@objc class AppDelegate: FlutterAppDelegate {
    // channel to communicate between flutter & Swift
    private var flutterChannel: FlutterMethodChannel?
    
    // tunnel status that seen by flutter
    private var flutterTunnelStatus: TunnelStatus = .off
    
    var statusObservationToken: Any? = nil
    
    // tunnel specific variables
    private var vpnManager: NETunnelProviderManager? = nil
    let bundleIdentifier = "tech.threefold.mycelium.MyceliumTunnel"
    let localizedDescription = "mycelium tunnel"
    let vpnUsername = "aiueo"
    let vpnServerAddress = "mycelium"

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
            flutterChannel = FlutterMethodChannel(name: "tech.threefold.mycelium/tun",
                                                  binaryMessenger: controller.binaryMessenger)
            flutterChannel!.setMethodCallHandler({
                (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
                // This method is invoked on the UI thread.
                switch call.method {
                case "generateSecretKey":
                    let key = generateSecretKey()
                    result(key)
                case "addressFromSecretKey":
                    if let key = call.arguments as? FlutterStandardTypedData {
                        let nodeAddr = addressFromSecretKey(data: key.data)
                        debuglog("nodeAddr = \(nodeAddr)")
                        result(nodeAddr)
                    } else {
                        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expect secret key", details: nil))
                    }
                case "startVpn":
                    if let arguments = call.arguments as? Dictionary<String, Any> {
                        let secretKey = arguments["secretKey"] as! FlutterStandardTypedData
                        let peers = arguments["peers"] as! [String]
                        self.flutterTunnelStatus = .started
                        self.createTunnel(secretKey: secretKey.data, peers: peers)
                        result(true)
                    } else {
                        result(false)
                    }
                case "stopVpn":
                    self.flutterTunnelStatus = .stopped
                    self.stopMycelium()
                    result(true)
                case "getPeerStatus":
                    self.getPeerStatusFromTunnel(result: result)
                case "proxyConnect":
                    if let arguments = call.arguments as? [String: Any],
                       let remote = arguments["remote"] as? String {
                        self.sendTunnelMessage(message: "proxyConnect:\(remote)", result: result)
                    } else {
                        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing remote parameter", details: nil))
                    }
                case "proxyDisconnect":
                    self.sendTunnelMessage(message: "proxyDisconnect", result: result)
                case "startProxyProbe":
                    self.sendTunnelMessage(message: "startProxyProbe", result: result)
                case "stopProxyProbe":
                    self.sendTunnelMessage(message: "stopProxyProbe", result: result)
                case "listProxies":
                    self.sendTunnelMessage(message: "listProxies", result: result)
                case "enableDeviceWideProxy":
                    self.enableDeviceWideProxy(result: result)
                case "disableDeviceWideProxy":
                    self.disableDeviceWideProxy(result: result)
                case "getProxyStatus":
                    self.getProxyStatus(result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            })
            infolog("initializing app")
            //NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: OperationQueue.main) { [weak self] notification in
              //  self?.vpnStatusDidChange(notification)
            //}
            statusObservationToken = observeVPNStatus()
            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

    override func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Insert code here to handle when the app is about to terminate
        self.stopMycelium()
        super.applicationWillTerminate(application)
    }

    func createTunnel(secretKey: Data, peers: [String], tryNum: Int = 0) {
        // tryNum == 1 is a special condition, it happens on very first run after installation.
        // in this case, we can't  use existing vpnManager, we need to do `loadAllFromPreferences`
        // again
        if tryNum != 1 {
            if let vpnManager = self.vpnManager {
                infolog("use existing vpnManager")
                self.startVpnTunnel(vpnManager: vpnManager, secretKey: secretKey, peers: peers)
                return
            }
        }

        NETunnelProviderManager.loadAllFromPreferences { (providers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                errlog("loadAllFromPref failed:" + error.localizedDescription)
                return
            }

            guard let providers = providers else {
                errlog("caught by the nil providers guard")
                return
            } // Handle error if nil

            if providers.count > 0 {
                // TODO : search by bundle identifier
                let myProvider = providers.first(where: { $0.protocolConfiguration?.serverAddress==self.vpnServerAddress })
                if let unwrappedProvider = myProvider { // cek nil
                    self.vpnManager = unwrappedProvider
                    debuglog("use existing provider")
                } else {
                    errlog("provider is null, creating a new one")
                    self.vpnManager = self.createVPN()
                }
            } else {
                infolog("no provider exists, creating a new one")
                self.vpnManager = self.createVPN()
            }
            guard self.vpnManager != nil else {
                errlog("vpnManager is unexpectedly nil")
                self.flutterChannel?.invokeMethod("vpnManager is unexpectedly nil", arguments: nil)
                return
            }
            let vpnManager = self.vpnManager! // it is safe to force it using `!` because of the `guard` above
            
            vpnManager.isEnabled = true
            
            vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    errlog("failed to save self.vpnManager: "+error.localizedDescription)
                } else {
                    infolog("preferences saved successfully")
                    // based on some QnA in the apple developer forums,
                    // very first run (which need to ask for user permission)  will always failed.
                    // The workaround is to retry the process, which we do here.
                    if vpnManager.connection.status == .invalid && tryNum == 0 {
                        infolog("it is on very first run, we need to retry the loadAllFromPreferences")
                        self.createTunnel(secretKey: secretKey, peers: peers, tryNum: 1)
                    } else {
                        self.startVpnTunnel(vpnManager: vpnManager, secretKey: secretKey, peers: peers)
                    }
                }
            })
        }
        
    }
    private func startVpnTunnel(vpnManager: NETunnelProviderManager, secretKey: Data, peers: [String]) {
        do {
            let options: [String: NSObject] = [
                "secretKey": secretKey as NSObject,
                "peers": peers as NSObject
            ]
            try vpnManager.connection.startVPNTunnel(options: options)
        } catch {
            errlog("startVPNTunnel() failed: " + error.localizedDescription)
        }
    }
    
    @objc func vpnStatusDidChange(_ notification: Notification) {
        if let vpnConnection = notification.object as? NETunnelProviderSession {
            let status = vpnConnection.status
            // Handle the status change
            switch status {
            case .connecting:
                infolog("VPN is connecting")
            case .connected:
                infolog("VPN is connected")
                self.flutterTunnelStatus = .running
                flutterChannel?.invokeMethod("notifyMyceliumStarted", arguments: nil)
            case .disconnecting:
                infolog("VPN is disconnecting")
            case .disconnected:
                infolog("VPN is disconnected")
                switch self.flutterTunnelStatus {
                case .off:
                    errlog("Unexpected: got .disconnected when flutterTunnelStatus = .off ")
                case .started:
                    // first disconnected, we can ignore it
                    debuglog("fist disconnected, we can ignore it")
                case .running:
                    errlog("mycelium failed")
                    flutterChannel?.invokeMethod("notifyMyceliumFailed", arguments: nil)
                case .stopped:
                    flutterChannel?.invokeMethod("notifyMyceliumFinished", arguments: nil)
                    return
                }
            case .invalid:
                infolog("VPN is invalid")
            case .reasserting:
                infolog("VPN is reasserting")
            @unknown default:
                infolog("VPN status is unknown")
            }
        }
    }

    func createVPN() -> NETunnelProviderManager {
        // create protocol configuration
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = self.bundleIdentifier
        providerProtocol.providerConfiguration = [:]
        providerProtocol.serverAddress = self.vpnServerAddress
        providerProtocol.username = self.vpnUsername
        
        providerProtocol.disconnectOnSleep = false
        
        // initialize the manager
        let vpnManager = NETunnelProviderManager()
        vpnManager.protocolConfiguration = providerProtocol
        vpnManager.localizedDescription = self.localizedDescription
        return vpnManager
        // rules
        /*
         let disconnectrule = NEOnDemandRuleDisconnect()
         var rules: [NEOnDemandRule] = [disconnectrule]
         let wifirule = NEOnDemandRuleConnect()
         wifirule.interfaceTypeMatch = .wiFi
         rules.insert(wifirule, at: 0)
         self.vpnManager.onDemandRules = rules
         self.vpnManager.isOnDemandEnabled = rules.count > 1*/
    }
    
    
    func stopMycelium() {
        infolog("stopMycelium")
        self.vpnManager?.connection.stopVPNTunnel()
    }
    
    // Tunnel-based communication methods
    private var cachedPeerStatus: [String]? = nil
    private var lastPeerStatusCall: Date = Date.distantPast
    private let peerStatusThrottleInterval: TimeInterval = 2.0
    
    // Generic tunnel message sender for proxy methods
    private func sendTunnelMessage(message: String, result: @escaping FlutterResult) {
        guard let vpnManager = self.vpnManager else {
            debuglog("VPN manager not available for \(message)")
            result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not available", details: nil))
            return
        }
        
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
            debuglog("Tunnel session not available for \(message)")
            result(FlutterError(code: "NO_TUNNEL_SESSION", message: "Tunnel session not available", details: nil))
            return
        }
        
        // Check if tunnel is connected
        guard session.status == .connected else {
            debuglog("Tunnel not connected (status: \(session.status.rawValue)) for \(message)")
            result(FlutterError(code: "TUNNEL_NOT_CONNECTED", message: "Tunnel not connected", details: nil))
            return
        }
        
        let messageData = message.data(using: .utf8)!
        
        do {
            try session.sendProviderMessage(messageData) { [weak self] responseData in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    guard let responseData = responseData else {
                        debuglog("No response data from tunnel for \(message)")
                        result(FlutterError(code: "NO_TUNNEL_RESPONSE", message: "No response from tunnel", details: nil))
                        return
                    }
                    
                    do {
                        // Try to parse as JSON first (for listProxies)
                        if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String] {
                            result(jsonResponse)
                        } else if let stringResponse = String(data: responseData, encoding: .utf8) {
                            // For simple string responses (like "ok")
                            result([stringResponse])
                        } else {
                            debuglog("Invalid response format from tunnel for \(message)")
                            result(FlutterError(code: "INVALID_TUNNEL_RESPONSE", message: "Invalid response format", details: nil))
                        }
                    } catch {
                        debuglog("Error parsing tunnel response for \(message): \(error.localizedDescription)")
                        result(FlutterError(code: "TUNNEL_PARSE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }
        } catch {
            debuglog("Error sending message to tunnel for \(message): \(error.localizedDescription)")
            result(FlutterError(code: "TUNNEL_MESSAGE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Device-Wide Proxy Methods
    
    private func enableDeviceWideProxy(result: @escaping FlutterResult) {
        infolog("iOS: Enabling device-wide SOCKS5 proxy")
        
        guard let vpnManager = self.vpnManager else {
            result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not available", details: nil))
            return
        }
        
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
            result(FlutterError(code: "NO_TUNNEL_SESSION", message: "Tunnel session not available", details: nil))
            return
        }
        
        guard session.status == .connected else {
            result(FlutterError(code: "TUNNEL_NOT_CONNECTED", message: "VPN tunnel must be connected first", details: nil))
            return
        }
        
        // Send message to tunnel extension to enable device-wide proxy
        let messageData = "enableDeviceWideProxy".data(using: .utf8)!
        
        do {
            try session.sendProviderMessage(messageData) { responseData in
                if let responseData = responseData,
                   let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let status = response["status"] as? String,
                   status == "enabled" {
                    infolog("iOS: Device-wide proxy enabled successfully")
                    result(true)
                } else {
                    errlog("iOS: Failed to enable device-wide proxy")
                    result(FlutterError(code: "PROXY_ENABLE_FAILED", message: "Failed to enable device-wide proxy", details: nil))
                }
            }
        } catch {
            errlog("iOS: Error sending enableDeviceWideProxy message: \(error.localizedDescription)")
            result(FlutterError(code: "MESSAGE_SEND_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func disableDeviceWideProxy(result: @escaping FlutterResult) {
        infolog("iOS: Disabling device-wide SOCKS5 proxy")
        
        guard let vpnManager = self.vpnManager else {
            result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not available", details: nil))
            return
        }
        
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
            result(FlutterError(code: "NO_TUNNEL_SESSION", message: "Tunnel session not available", details: nil))
            return
        }
        
        guard session.status == .connected else {
            result(FlutterError(code: "TUNNEL_NOT_CONNECTED", message: "VPN tunnel must be connected first", details: nil))
            return
        }
        
        // Send message to tunnel extension to disable device-wide proxy
        let messageData = "disableDeviceWideProxy".data(using: .utf8)!
        
        do {
            try session.sendProviderMessage(messageData) { responseData in
                if let responseData = responseData,
                   let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let status = response["status"] as? String,
                   status == "disabled" {
                    infolog("iOS: Device-wide proxy disabled successfully")
                    result(true)
                } else {
                    errlog("iOS: Failed to disable device-wide proxy")
                    result(FlutterError(code: "PROXY_DISABLE_FAILED", message: "Failed to disable device-wide proxy", details: nil))
                }
            }
        } catch {
            errlog("iOS: Error sending disableDeviceWideProxy message: \(error.localizedDescription)")
            result(FlutterError(code: "MESSAGE_SEND_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func getProxyStatus(result: @escaping FlutterResult) {
        guard let vpnManager = self.vpnManager else {
            let status = [
                "enabled": false,
                "socksEnabled": false,
                "error": "VPN manager not available"
            ]
            result(status)
            return
        }
        
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
            let status = [
                "enabled": false,
                "socksEnabled": false,
                "error": "Tunnel session not available"
            ]
            result(status)
            return
        }
        
        guard session.status == .connected else {
            let status = [
                "enabled": false,
                "socksEnabled": false,
                "error": "Tunnel not connected"
            ]
            result(status)
            return
        }
        
        // Send message to tunnel extension to get proxy status
        let messageData = "getProxyStatus".data(using: .utf8)!
        
        do {
            try session.sendProviderMessage(messageData) { responseData in
                if let responseData = responseData,
                   let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                    result(response)
                } else {
                    let status = [
                        "enabled": false,
                        "socksEnabled": false,
                        "error": "Failed to get proxy status"
                    ]
                    result(status)
                }
            }
        } catch {
            let status = [
                "enabled": false,
                "socksEnabled": false,
                "error": error.localizedDescription
            ]
            result(status)
        }
    }
    
    private func getPeerStatusFromTunnel(result: @escaping FlutterResult) {
        let now = Date()
        
        // Throttle requests to prevent excessive calls
        if now.timeIntervalSince(lastPeerStatusCall) < peerStatusThrottleInterval {
            if let cached = cachedPeerStatus {
                debuglog("Returning cached peer status (throttled)")
                result(cached)
                return
            }
        }
        
        lastPeerStatusCall = now
        
        guard let vpnManager = self.vpnManager else {
            debuglog("VPN manager not available, returning cached result or error")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not available", details: nil))
            }
            return
        }
        
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
            debuglog("Tunnel session not available, returning cached result or error")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(FlutterError(code: "NO_TUNNEL_SESSION", message: "Tunnel session not available", details: nil))
            }
            return
        }
        
        // Check if tunnel is connected
        guard session.status == .connected else {
            debuglog("Tunnel not connected (status: \(session.status.rawValue)), returning cached result or error")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(["err_tunnel_not_connected"])
            }
            return
        }
        
        let messageData = "getPeerStatus".data(using: .utf8)!
        
        do {
            try session.sendProviderMessage(messageData) { [weak self] responseData in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    guard let responseData = responseData else {
                        debuglog("No response data from tunnel, returning cached result or error")
                        if let cached = self.cachedPeerStatus {
                            result(cached)
                        } else {
                            result(["err_no_tunnel_response"])
                        }
                        return
                    }
                    
                    do {
                        if let peerStatus = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String] {
                            self.cachedPeerStatus = peerStatus
                            result(peerStatus)
                        } else {
                            if let cached = self.cachedPeerStatus {
                                result(cached)
                            } else {
                                result(["err_invalid_tunnel_response"])
                            }
                        }
                    } catch {
                        debuglog("Error parsing tunnel response: \(error.localizedDescription)")
                        if let cached = self.cachedPeerStatus {
                            result(cached)
                        } else {
                            result(["err_tunnel_parse_error"])
                        }
                    }
                }
            }
        } catch {
            debuglog("Error sending message to tunnel: \(error.localizedDescription)")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(FlutterError(code: "TUNNEL_MESSAGE_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        infolog("applicationDidBecomeActive wake up")
        flutterChannel?.invokeMethod("notifyAppWakeup", arguments: nil)
    }

    func observeVPNStatus() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: OperationQueue.main) { [weak self] notification in
            self?.vpnStatusDidChange(notification)
        }
    }
}

enum TunnelStatus {
    case off
    case started
    case running
    case stopped
}

func debuglog(_ msg: String, _ args: CVarArg...) {
    mlog(msg, .debug, args)
}

func infolog(_ msg: String, _ args: CVarArg...) {
    mlog(msg, .info, args)
}

func errlog(_ msg: String, _ args: CVarArg...) {
    mlog(msg, .error, args)
}

func mlog(_ msg: String,_ type: OSLogType, _ args: CVarArg...) {
    os_log("%{public}@ %{public}@", log: .default, type: type, "myceliumflut:AppDelegate:", String(describing: msg), args)
}



// NotificationToken and NotificationCenter was taken from https://oleb.net/blog/2018/01/notificationcenter-removeobserver/
final class NotificationToken {
    let notificationCenter: NotificationCenter
    let token: Any

    init(notificationCenter: NotificationCenter = .default, token: Any) {
        self.notificationCenter = notificationCenter
        self.token = token
    }

    deinit {
        notificationCenter.removeObserver(token)
    }
}

extension NotificationCenter {
    /// Convenience wrapper for addObserver(forName:object:queue:using:)
    /// that returns our custom `NotificationToken`.
    func observe(name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NotificationToken {
        let token = addObserver(forName: name, object: obj, queue: queue, using: block)
        return NotificationToken(notificationCenter: self, token: token)
    }
}