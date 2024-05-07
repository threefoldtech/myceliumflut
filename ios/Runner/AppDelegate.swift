import UIKit
import Flutter
import NetworkExtension
import Foundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    var vpnManager: NETunnelProviderManager = NETunnelProviderManager()
    let componentName = "tech.threefold.mycelium.MyceliumTunnel"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
            let tunChannel = FlutterMethodChannel(name: "tech.threefold.mycelium/tun",
                                                  binaryMessenger: controller.binaryMessenger)
            tunChannel.setMethodCallHandler({
                [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
                // This method is invoked on the UI thread.
                switch call.method {
                case "getBatteryLevel":
                    result(90)
                case "startVpn":
                    result(true)
                case "getTunFD":
                    result(1)
                default:
                    result(FlutterMethodNotImplemented)
                }
            })
            NSLog("iwanbk1 flutter app")

            GeneratedPluginRegistrant.register(with: self)
            //self.vpnTunnelProviderManagerInit()
            self.initTunnel()
            //self.vpnTunnelProviderManagerInit()

            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

    func initTunnel() {
        NETunnelProviderManager.loadAllFromPreferences { (providers: [NETunnelProviderManager]?, error: Error?) in

            if let error = error {
                NSLog("iwanbk1 loadAllFromPref failed:" + error.localizedDescription)
                return
            }

            guard let providers = providers else {
                NSLog("iwanbk1 caught by the guard")
                return
            } // Handle error if nil

            NSLog("iwanbk1 passed the guard")

            NSLog("iwanbk1 number of providers : %d", providers.count)

            let myProvider = providers.first(where: { $0.protocolConfiguration?.username == "" }) // Replace with your identifier

            NSLog("iwanbk1 enabling provider")
            myProvider?.isEnabled = true
            NSLog("iwanbk1 passed myprovider isEnabled")
            do {
                NSLog("iwanbk1 connection.startVPNTUnnel")
                try myProvider?.connection.startVPNTunnel()
            } catch {
                print(error)
                NSLog("iwanbk1 start vpn tunnel failed" )
            }

            /*myProvider?.saveToPreferences { error in
             if let error = error {
             NSLog("iwanbk1 failed to save preference %s", error.localizedDescription)
             } else {
             NSLog("iwanbk1 saveToPreference ga error")
             do {
             NSLog("iwanbk1 connection.startVPNTUnnel")
             try myProvider?.connection.startVPNTunnel()
             } catch {
             print(error)
             NSLog("iwanbk1 start vpn tunnel failed" )
             }
             }
             }*/
        }
    }
    func vpnTunnelProviderManagerInit() {
        NETunnelProviderManager.loadAllFromPreferences { (savedManagers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                NSLog("iwanbk1 loadAllFromPref failed:" + error.localizedDescription)
            } else {
                let count = savedManagers?.count ?? 0
                NSLog("iwanbk1 number of savedManagers : %d", count)

                if let savedManagers = savedManagers {
                    for manager in savedManagers {
                        NSLog("found some saved manager")
                        if (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.componentName {
                            NSLog("iwanbk found saved vpn manager")
                            self.vpnManager = manager
                        }
                    }
                }

                // start here
                self.vpnManager.isEnabled = true
                do {
                    try self.vpnManager.connection.startVPNTunnel()
                } catch {
                    NSLog("start vpn tunnel failed: " + error.localizedDescription)
                }
            }
        }
    }
}
