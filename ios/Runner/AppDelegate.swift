import UIKit
import Flutter
import NetworkExtension
import Foundation
import OSLog

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    var vpnManager: NETunnelProviderManager = NETunnelProviderManager()
    let bundleIdentifier = "tech.threefold.mycelium.MyceliumTunnel"
    let localizedDescription = "mycelium tunnel"
    let vpnUsername = "aiueo"
    let vpnServerAddress = "mycelium"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
            let tunChannel = FlutterMethodChannel(name: "tech.threefold.mycelium/tun",
                                                  binaryMessenger: controller.binaryMessenger)
            tunChannel.setMethodCallHandler({
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
                        self.createTunnel(secretKey: secretKey.data, peers: peers)
                        result(true) // TODO: check return value of the self.createTunnel
                    } else {
                        result(false)
                    }
                case "stopVpn":
                    self.stopMycelium()
                    result(true)
                case "getTunFD":
                    result(1)
                default:
                    result(FlutterMethodNotImplemented)
                }
            })
            infolog("initializing app")

            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Insert code here to handle when the app is about to terminate
        errlog("applicationWillterminate handler empty")
        self.stopMycelium()
        super.applicationWillTerminate(application)
    }
/*
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
    func createTunnel(secretKey: Data, peers: [String]) {
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
                infolog("number of providers :\(providers.count)")
                // TODO : search by bundle identifier
                let myProvider = providers.first(where: { $0.protocolConfiguration?.serverAddress==self.vpnServerAddress }) // Replace with your identifier
                if let unwrappedProvider = myProvider { // cek nil
                    self.vpnManager = unwrappedProvider
                    debuglog("use existing provider")
                } else {
                    debuglog("provider is Nil, creating a new one")
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
                }
            })
            do {
                debuglog("connection.startVPNTUnnel")
                var options: [String: NSObject] = [
                    "secretKey": secretKey as NSObject,
                    "peers": peers as NSObject
                ]
                try self.vpnManager.connection.startVPNTunnel(options: options)
            } catch {
                errlog("startVPNTunnel() failed: " + error.localizedDescription)
            }
        }
        
    }
    
    func createVPN() {
        // create protocol configuration
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = self.bundleIdentifier
        providerProtocol.providerConfiguration = [:]
        providerProtocol.serverAddress = self.vpnServerAddress
        providerProtocol.username = self.vpnUsername
        
        providerProtocol.disconnectOnSleep = true // TODO: check this
        
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
