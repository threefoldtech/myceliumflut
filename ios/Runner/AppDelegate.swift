import UIKit
import Flutter
import NetworkExtension
import Foundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    var vpnManager: NETunnelProviderManager = NETunnelProviderManager()
    let bundleIdentifier = "tech.threefold.mycelium.MyceliumTunnel"

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
                        NSLog("[appDeleteGate] xnode addr = %s", nodeAddr)
                        result(nodeAddr)
                    } else {
                        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expect secret key", details: nil))
                    }
                case "startVpn":
                    self.createTunnel()
                    result(true)
                case "stopVpn":
                    print("stopVpn:")
                    self.stopMycelium()
                    result(true)
                case "getTunFD":
                    result(1)
                default:
                    result(FlutterMethodNotImplemented)
                }
            })
            NSLog("iwanbk1 flutter app")

            GeneratedPluginRegistrant.register(with: self)
            //self.createTunnel()
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
    
    func createTunnel() {
        NETunnelProviderManager.loadAllFromPreferences { (providers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                NSLog("iwanbk1 loadAllFromPref failed:" + error.localizedDescription)
                return
            }

            guard let providers = providers else {
                NSLog("iwanbk1 caught by the guard")
                return
            } // Handle error if nil
            if providers.count > 0 {
                NSLog("iwanbk1 number of providers : %d", providers.count)
                
                // TODO : search by bundle identifier
                let myProvider = providers.first(where: { $0.protocolConfiguration?.username=="aiueo" }) // Replace with your identifier
                
                if let unwrappedProvider = myProvider { // cek nil
                    self.vpnManager = unwrappedProvider
                    NSLog("use existing provider")
                    self.vpnManager.isEnabled = true
                    //unwrappedProvider.isEnabled = true
                    //self.vpnManager = unwrappedProvider
                    
                    self.vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                        if let error = error {
                            NSLog("failed to save self.vpnManager: "+error.localizedDescription)
                            //return
                        } else {
                            NSLog("unwrappedProvider saved successfully")
                            //NotificationCenter.default.post(name: NSNotification.Name.YggdrasilSettingsUpdated, object: self)
                        }
                    })
                    self.VPNStatusDidChange(nil)
                    NSLog("out from VPN Status Did Change")

                    do {
                        NSLog("iwanbk1 [unwrappedProvider] connection.startVPNTUnnel")
                        try self.vpnManager.connection.startVPNTunnel()
                        NSLog("iwanbk1 [unwrappedProvider] looks like connection.startVPNTUnnel works?")
                    } catch {
                        NSLog("ibk1 [unwrappedProvider] startVPNTunnel() failed: " + error.localizedDescription)
                    }
                    return
                }
                NSLog("myProvider is Nil, creating a new one")
            }   
            NSLog("no provider exists, creating a new one")
            // create protocol configuration
            let providerProtocol = NETunnelProviderProtocol()
            providerProtocol.providerBundleIdentifier = self.bundleIdentifier
            providerProtocol.providerConfiguration = [:]
            providerProtocol.serverAddress = "mycelium"
            providerProtocol.username = "aiueo"
            
            //providerProtocol.passwordReference = "uuuuuuu"
            providerProtocol.disconnectOnSleep = true
            
            // initialize the manager
            self.vpnManager = NETunnelProviderManager()
            self.vpnManager.protocolConfiguration = providerProtocol
            self.vpnManager.localizedDescription = "mycelium tunnel"
            
            // rules
            let disconnectrule = NEOnDemandRuleDisconnect()
            var rules: [NEOnDemandRule] = [disconnectrule]
            
            let wifirule = NEOnDemandRuleConnect()
            wifirule.interfaceTypeMatch = .wiFi
            rules.insert(wifirule, at: 0)
            

            self.vpnManager.onDemandRules = rules
            self.vpnManager.isOnDemandEnabled = rules.count > 1
            
            self.vpnManager.isEnabled = true
            
            
            self.vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    NSLog("failed to save new provider: "+error.localizedDescription)
                    //return
                } else {
                    NSLog("new provider saved successfully")
                    //NotificationCenter.default.post(name: NSNotification.Name.YggdrasilSettingsUpdated, object: self)
                }
            })
            //self.VPNStatusDidChange(nil)
            do {
                NSLog("iwanbk1 [new provider] connection.startVPNTUnnel")
                try  self.vpnManager.connection.startVPNTunnel()
            } catch {
                NSLog("ibk1 [new provider] startVPNTunne() failed: " + error.localizedDescription)
            }
        }
        
    }
    
    /*func startMycelium() {
        NSLog("startMycelium")
        
        self.vpnManager.loadFromPreferences { (error:Error?) in
            if let error = error {
                NSLog("loadFromPref failed:"+error.localizedDescription)
            }
            
            do {
                NSLog("iwanbk1 startMycelium startVPNTunel")
                try self.vpnManager.connection.startVPNTunnel()
                NSLog("iwanbk1 startMycelium startVPNTunel looks fine?")
            } catch {
                NSLog("self.vpnManager.connection.startVPNTunnel() failed:"+error.localizedDescription)
            }
            
        }
    }*/
    
    func stopMycelium() {
        NSLog("startMycelium")
        
        self.vpnManager.loadFromPreferences { (error:Error?) in
            if let error = error {
                NSLog("loadFromPref failed:"+error.localizedDescription)
            }
            
            do {
                NSLog("iwanbk1 startMycelium stopVPNTunnel")
                try self.vpnManager.connection.stopVPNTunnel()
                NSLog("iwanbk1 startMycelium stopVPNTunel looks fine?")
            } catch {
                NSLog("self.vpnManager.connection.stopVPNTunnel() failed:"+error.localizedDescription)
            }
            
        }
    }
     
    
    func VPNStatusDidChange(_ notification: Notification?) {
            print("VPN Status changed:")
            let status = self.vpnManager.connection.status
            switch status {
            case .connecting:
                print("Connecting...")
                //connectButton.setTitle("Disconnect", for: .normal)
                break
            case .connected:
                print("Connected...")
                //connectButton.setTitle("Disconnect", for: .normal)
                break
            case .disconnecting:
                print("Disconnecting...")
                break
            case .disconnected:
                print("Disconnected...")
                //connectButton.setTitle("Connect", for: .normal)
                break
            case .invalid:
                print("Invliad")
                break
            case .reasserting:
                print("Reasserting...")
                break
            }
        }
    
}
