import UIKit
import Flutter
import NetworkExtension
import Foundation

// TODO:
// - do logger properly, get rid of NSLog

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
                        NSLog("nodeAddr = \(nodeAddr)")
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
            NSLog("initializing myceliumflut")

            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
    
    func createTunnel(secretKey: Data, peers: [String]) {
        NETunnelProviderManager.loadAllFromPreferences { (providers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                NSLog("myceliumflut MyceliumTunnel loadAllFromPref failed:" + error.localizedDescription)
                return
            }
            guard let providers = providers else {
                NSLog("myceliumflut MyceliumTunnel caught by the nil providers guard")
                return
            } // Handle error if nil
            if providers.count > 0 {
                NSLog("myceliumflut MyceliumTunnel number of providers : %d", providers.count)
                // TODO : search by bundle identifier
                let myProvider = providers.first(where: { $0.protocolConfiguration?.serverAddress==self.vpnServerAddress }) // Replace with your identifier
                
                if let unwrappedProvider = myProvider { // cek nil
                    self.vpnManager = unwrappedProvider
                    NSLog("myceliumflut MyceliumTunnel use existing provider")
                } else {
                    NSLog("myceliumflut MyceliumTunnel provider is Nil, creating a new one")
                    self.createVPN()
                }
            } else {
                NSLog("myceliumflut MyceliumTunnel no provider exists, creating a new one")
                self.createVPN()
            }
            
           
            self.vpnManager.isEnabled = true
            
            self.vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    NSLog("myceliumflut MyceliumTunnel failed to save self.vpnManager: "+error.localizedDescription)
                } else {
                    NSLog("myceliumflut MyceliumTunnel preferences saved successfully")
                }
            })
            do {
                NSLog("myceliumflut MyceliumTunnel connection.startVPNTUnnel")
                var options: [String: NSObject] = [
                    "secretKey": secretKey as NSObject,
                    "peers": peers as NSObject
                ]
                try self.vpnManager.connection.startVPNTunnel(options: options)
            } catch {
                NSLog("myceliumflut MyceliumTunnel startVPNTunnel() failed: " + error.localizedDescription)
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
        NSLog("stopMycelium")
        self.vpnManager.connection.stopVPNTunnel()
    }
}
