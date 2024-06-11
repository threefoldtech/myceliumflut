import UIKit
import Flutter
import NetworkExtension
import Foundation
import OSLog

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    // channel to communicate between flutter & Swift
    private var flutterChannel: FlutterMethodChannel?
    
    // tunnel status that seen by flutter
    private var flutterTunnelStatus: TunnelStatus = .off
    
    //var observer: Any? = nil
    
    // tunnel specific variables
    var vpnManager: NETunnelProviderManager = NETunnelProviderManager()
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
                    if let arguments = call.arguments as? Dictionary<String, Any> {
                        let secretKey = arguments["secretKey"] as! FlutterStandardTypedData
                        let peers = arguments["peers"] as! [String]
                        
                        errlog("ADDING OBSERVER")
                        NotificationCenter.default.addObserver(self, selector: #selector(self.vpnStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
                        
                        self.flutterTunnelStatus = .started
                        self.createTunnel(secretKey: secretKey.data, peers: peers)
                        result(true) // TODO: check return value of the self.createTunnel
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
            infolog("initializing app")
            
            //errlog("ADDING OBSERVER")
            //NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)

            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

    override func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Insert code here to handle when the app is about to terminate
        errlog("applicationWillterminate handler empty")
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        self.stopMycelium()
        super.applicationWillTerminate(application)
    }

    func createTunnel(secretKey: Data, peers: [String], tryNum: Int = 0) {
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
                    self.createVPN()
                }
            } else {
                infolog("no provider exists, creating a new one")
                self.createVPN()
            }
            
            self.vpnManager.isEnabled = true
            
            self.vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    errlog("failed to save self.vpnManager: "+error.localizedDescription)
                } else {
                    infolog("preferences saved successfully")
                    do {
                        // based on some QnA in the apple developer forums,
                        // very first run (which need to ask for user permission)  will always failed.
                        // The workaround is to retry the process, which we do here.
                        if self.vpnManager.connection.status == .invalid && tryNum == 0 {
                            infolog("it is on very first run, we need to retry the loadAllFromPreferences")
                            self.createTunnel(secretKey: secretKey, peers: peers, tryNum: 1)
                        } else {
                            let options: [String: NSObject] = [
                                "secretKey": secretKey as NSObject,
                                "peers": peers as NSObject
                            ]
                            try self.vpnManager.connection.startVPNTunnel(options: options)
                        }
                    } catch {
                        errlog("startVPNTunnel() failed: " + error.localizedDescription)
                    }
                }
            })
        }
        
    }
    
    @objc func vpnStatusDidChange(_ notification: Notification) {
        errlog("call vpnStatusDidChange func")
        if let vpnConnection = notification.object as? NEVPNConnection {
            let status = vpnConnection.status
            // Handle the status change
            switch status {
            case .connecting:
                infolog("VPN is connecting")
                //NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
            case .connected:
                infolog("VPN is connected")
                self.flutterTunnelStatus = .running
                flutterChannel?.invokeMethod("notifyMyceliumStarted", arguments: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
            case .disconnecting:
                infolog("VPN is disconnecting")
                //NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
            case .disconnected:
                infolog("VPN is disconnected")
                switch self.flutterTunnelStatus {
                case .off:
                    errlog("Unexpected: got .disconnected when flutterTunnelStatus = .off ")
                case .started:
                    // first disconnected, we can ignore it
                    debuglog("fist disconnected, we can ignore it")
                    //NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
                case .running:
                    errlog("mycelium failed")
                    flutterChannel?.invokeMethod("notifyMyceliumFailed", arguments: nil)
                    //NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
                case .stopped:
                    flutterChannel?.invokeMethod("notifyMyceliumFinished", arguments: nil)
                    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
                    //NotificationCenter.default.removeObserver(self.observer!)
                    return
                }
            case .invalid:
                infolog("VPN is invalid")
            case .reasserting:
                infolog("VPN is reasserting")
            @unknown default:
                infolog("VPN status is unknown")
            }
            //NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        }
    }

    func createVPN() {
        // create protocol configuration
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = self.bundleIdentifier
        providerProtocol.providerConfiguration = [:]
        providerProtocol.serverAddress = self.vpnServerAddress
        providerProtocol.username = self.vpnUsername
        
        providerProtocol.disconnectOnSleep = false
        
        // initialize the manager
        self.vpnManager = NETunnelProviderManager()
        self.vpnManager.protocolConfiguration = providerProtocol
        self.vpnManager.localizedDescription = self.localizedDescription
        
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
        self.vpnManager.connection.stopVPNTunnel()
    }

    /*
     TODO: add some handlers to below func
     func applicationWillResignActive(_ application: UIApplication) {
     // Pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates.
     // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks.
     }

     func applicationDidEnterBackground(_ application: UIApplication) {
     // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
     }

     func applicationWillEnterForeground(_ application: UIApplication) {
     // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
     }

     func applicationDidBecomeActive(_ application: UIApplication) {
     // Restart any tasks that were paused (or not yet started) while the application was inactive.
     }
     */
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
