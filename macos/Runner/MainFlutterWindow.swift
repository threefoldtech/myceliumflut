import Cocoa
import FlutterMacOS
import IOKit.ps
import OSLog
import NetworkExtension

class MainFlutterWindow: NSWindow {
    // channel to communicate between flutter & Swift
    private var flutterChannel: FlutterMethodChannel?
    // tunnel status that seen by flutter
    private var flutterTunnelStatus: TunnelStatus = .off
    
    var statusObservationToken: Any? = nil
    
    // tunnel specific variables
    private var vpnManager: NETunnelProviderManager? = nil
    let bundleIdentifier = "tech.threefold.mycelium.MyceliumTunnel"
    let localizedDescription = "mycelium tunnel"
    let vpnUsername = "masterOfMycel"
    let vpnServerAddress = "mycelium"

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        flutterChannel = FlutterMethodChannel(name: "tech.threefold.mycelium/tun",
                                                  binaryMessenger: flutterViewController.engine.binaryMessenger)
        
        flutterChannel?.setMethodCallHandler({
            (call: FlutterMethodCall, result: FlutterResult) -> Void in
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
                infolog("CALLING STARTVPN\n\n\n\n   ")
                print("iwanbk CALLING STARTT VPN TEAMS!")
                if let arguments = call.arguments as? Dictionary<String, Any> {
                    let secretKey = arguments["secretKey"] as! FlutterStandardTypedData
                    let peers = arguments["peers"] as! [String]
                    self.flutterTunnelStatus = .started
                    print("WANT TO CREATE TUNNEL")
                    self.createTunnel(secretKey: secretKey.data, peers: peers)
                    result(true)
                } else {
                    result(false)
                }
            case "stopVpn":
                self.flutterTunnelStatus = .stopped
                self.stopMycelium()
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        statusObservationToken = observeVPNStatus()
        
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
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
                infolog("VPN is disconnected.desc:" + notification.description + ". debug desc:" + notification.debugDescription)
                switch self.flutterTunnelStatus {
                case .off:
                    errlog("Unexpected: got .disconnected when flutterTunnelStatus = .off ")
                case .started:
                    // first disconnected, we can ignore it
                    debuglog("first disconnected, we can ignore it")
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
        providerProtocol.excludeLocalNetworks = true
        
        providerProtocol.disconnectOnSleep = false
        
        // initialize the manager
        let vpnManager = NETunnelProviderManager()
        vpnManager.protocolConfiguration = providerProtocol
        vpnManager.localizedDescription = self.localizedDescription
        
        return vpnManager
    }
    
    
    func stopMycelium() {
        infolog("stopMycelium")
        self.vpnManager?.connection.stopVPNTunnel()
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
    os_log("%{public}@ %{public}@", log: .default, type: type, "myceliumflut:MainFlutterWindow:", String(describing: msg), args)
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
