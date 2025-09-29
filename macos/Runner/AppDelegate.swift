import Cocoa
import FlutterMacOS
import flutter_desktop_sleep
import SystemConfiguration

@main
class AppDelegate: FlutterAppDelegate {
    var _windowManager = FlutterDesktopSleepPlugin()
    private var flutterChannel: FlutterMethodChannel?
    private var isMyceliumRunning = false
    private var myceliumStartTask: Task<Void, Never>?
    
    // System proxy management
    private let socksProxyHost = "127.0.0.1"
    private let socksProxyPort = 1080
    private var originalProxySettings: [String: Any] = [:]
    private var isProxyEnabled = false
    
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
            case "startVpn":
                if let arguments = call.arguments as? Dictionary<String, Any> {
                    let secretKey = arguments["secretKey"] as! FlutterStandardTypedData
                    let peers = arguments["peers"] as! [String]
                    self.startMyceliumService(secretKey: secretKey.data, peers: peers, result: result)
                } else {
                    result(false)
                }
            case "stopVpn":
                self.stopMyceliumService(result: result)
            case "getPeerStatus":
                self.getPeerStatusFromService(result: result)
            case "proxyConnect":
                if let arguments = call.arguments as? [String: Any],
                   let remote = arguments["remote"] as? String {
                    self.handleProxyConnect(remote: remote, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing remote parameter", details: nil))
                }
            case "proxyDisconnect":
                self.handleProxyDisconnect(result: result)
            case "startProxyProbe":
                self.handleStartProxyProbe(result: result)
            case "stopProxyProbe":
                self.handleStopProxyProbe(result: result)
            case "listProxies":
                self.handleListProxies(result: result)
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
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Mycelium Service Methods
    
    private func startMyceliumService(secretKey: Data, peers: [String], result: @escaping FlutterResult) {
        print("macOS: Starting Mycelium service with peers: \(peers)")
        
        // Cancel any existing start task
        myceliumStartTask?.cancel()
        
        myceliumStartTask = Task {
            do {
                // Start Mycelium service using FFI
                startMycelium(peers: peers, tunFd: 0, secretKey: secretKey)
                
                await MainActor.run {
                    self.isMyceliumRunning = true
                    print("macOS: Mycelium service started successfully")
                    
                    // Notify Flutter that Mycelium started
                    self.flutterChannel?.invokeMethod("notifyMyceliumStarted", arguments: nil)
                    result(true)
                }
            } catch {
                await MainActor.run {
                    print("macOS: Failed to start Mycelium service: \(error)")
                    self.flutterChannel?.invokeMethod("notifyMyceliumFailed", arguments: error.localizedDescription)
                    result(false)
                }
            }
        }
    }
    
    private func stopMyceliumService(result: @escaping FlutterResult) {
        print("macOS: Stopping Mycelium service")
        
        // Cancel start task if running
        myceliumStartTask?.cancel()
        myceliumStartTask = nil
        
        Task {
            do {
                // Stop Mycelium service using FFI
                stopMycelium()
                
                await MainActor.run {
                    self.isMyceliumRunning = false
                    print("macOS: Mycelium service stopped successfully")
                    
                    // Notify Flutter that Mycelium finished
                    self.flutterChannel?.invokeMethod("notifyMyceliumFinished", arguments: nil)
                    result(true)
                }
            } catch {
                await MainActor.run {
                    print("macOS: Error stopping Mycelium service: \(error)")
                    result(false)
                }
            }
        }
    }
    
    private func getPeerStatusFromService(result: @escaping FlutterResult) {
        // Run peer status check in background to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            // Check if Mycelium service is running
            guard self.isMyceliumRunning else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SERVICE_NOT_RUNNING", message: "Mycelium service is not running", details: nil))
                }
                return
            }
            
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
    
    // MARK: - Device-Wide Proxy Methods
    
    private func enableDeviceWideProxy(result: @escaping FlutterResult) {
        print("macOS: Enabling device-wide SOCKS5 proxy")
        
        DispatchQueue.global(qos: .background).async {
            let success = self.enableSystemProxy()
            
            DispatchQueue.main.async {
                if success {
                    print("macOS: Device-wide proxy enabled successfully")
                    result(true)
                } else {
                    print("macOS: Failed to enable device-wide proxy")
                    result(FlutterError(code: "PROXY_ENABLE_FAILED", message: "Failed to configure system proxy settings", details: nil))
                }
            }
        }
    }
    
    private func disableDeviceWideProxy(result: @escaping FlutterResult) {
        print("macOS: Disabling device-wide SOCKS5 proxy")
        
        DispatchQueue.global(qos: .background).async {
            let success = self.disableSystemProxy()
            
            DispatchQueue.main.async {
                if success {
                    print("macOS: Device-wide proxy disabled successfully")
                    result(true)
                } else {
                    print("macOS: Failed to disable device-wide proxy")
                    result(FlutterError(code: "PROXY_DISABLE_FAILED", message: "Failed to restore original proxy settings", details: nil))
                }
            }
        }
    }
    
    private func getProxyStatus(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let status = [
                "enabled": self.isProxyEnabled,
                "host": self.socksProxyHost,
                "port": self.socksProxyPort,
                "type": "SOCKS5"
            ] as [String : Any]
            
            DispatchQueue.main.async {
                result(status)
            }
        }
    }
    
    // MARK: - Proxy Methods
    
    private func handleProxyConnect(remote: String, result: @escaping FlutterResult) {
        print("macOS: Connecting to SOCKS5 proxy: \(remote)")
        
        // Run proxy connect in background to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                let proxyResult = proxyConnect(remote: remote)
                DispatchQueue.main.async {
                    print("macOS: Proxy connect result: \(proxyResult)")
                    result(proxyResult)
                }
            } catch {
                DispatchQueue.main.async {
                    print("macOS: Error connecting to proxy: \(error)")
                    result(FlutterError(code: "PROXY_CONNECT_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleProxyDisconnect(result: @escaping FlutterResult) {
        print("macOS: Disconnecting from SOCKS5 proxy")
        
        // Run proxy disconnect in background to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                let proxyResult = proxyDisconnect()
                DispatchQueue.main.async {
                    print("macOS: Proxy disconnect result: \(proxyResult)")
                    result(proxyResult)
                }
            } catch {
                DispatchQueue.main.async {
                    print("macOS: Error disconnecting from proxy: \(error)")
                    result(FlutterError(code: "PROXY_DISCONNECT_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleStartProxyProbe(result: @escaping FlutterResult) {
        print("macOS: Starting proxy probe")
        
        // Run proxy probe start in background to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                let proxyResult = startProxyProbe()
                DispatchQueue.main.async {
                    print("macOS: Start proxy probe result: \(proxyResult)")
                    result(proxyResult)
                }
            } catch {
                DispatchQueue.main.async {
                    print("macOS: Error starting proxy probe: \(error)")
                    result(FlutterError(code: "PROXY_PROBE_START_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleStopProxyProbe(result: @escaping FlutterResult) {
        print("macOS: Stopping proxy probe")
        
        // Run proxy probe stop in background to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                let proxyResult = stopProxyProbe()
                DispatchQueue.main.async {
                    print("macOS: Stop proxy probe result: \(proxyResult)")
                    result(proxyResult)
                }
            } catch {
                DispatchQueue.main.async {
                    print("macOS: Error stopping proxy probe: \(error)")
                    result(FlutterError(code: "PROXY_PROBE_STOP_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleListProxies(result: @escaping FlutterResult) {
        print("macOS: Listing available proxies")
        
        // Run list proxies in background to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                let proxies = listProxies()
                DispatchQueue.main.async {
                    print("macOS: Available proxies: \(proxies)")
                    result(proxies)
                }
            } catch {
                DispatchQueue.main.async {
                    print("macOS: Error listing proxies: \(error)")
                    result(FlutterError(code: "PROXY_LIST_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Application Lifecycle
    
    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Clean up proxy settings before terminating
        if isProxyEnabled {
            _ = disableSystemProxy()
        }
        
        // Stop Mycelium service
        if isMyceliumRunning {
            stopMycelium()
        }
        
        let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        return _windowManager.applicationShouldTerminate(controller);
    }
    
    // MARK: - System Proxy Implementation
    
    private func enableSystemProxy() -> Bool {
        print("SystemProxy: Enabling device-wide SOCKS5 proxy...")
        
        // First, backup current proxy settings
        guard backupCurrentProxySettings() else {
            print("SystemProxy: Failed to backup current proxy settings")
            return false
        }
        
        // Configure system to use SOCKS5 proxy
        guard configureSystemSOCKSProxy() else {
            print("SystemProxy: Failed to configure SOCKS5 proxy")
            return false
        }
        
        isProxyEnabled = true
        print("SystemProxy: Device-wide SOCKS5 proxy enabled successfully")
        return true
    }
    
    private func disableSystemProxy() -> Bool {
        print("SystemProxy: Disabling device-wide SOCKS5 proxy...")
        
        guard isProxyEnabled else {
            print("SystemProxy: Proxy is not currently enabled")
            return true
        }
        
        guard restoreOriginalProxySettings() else {
            print("SystemProxy: Failed to restore original proxy settings")
            return false
        }
        
        isProxyEnabled = false
        originalProxySettings.removeAll()
        print("SystemProxy: Device-wide SOCKS5 proxy disabled successfully")
        return true
    }
    
    private func backupCurrentProxySettings() -> Bool {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            print("SystemProxy: Failed to create SCDynamicStore")
            return false
        }
        
        // Get list of network services
        guard let networkServices = getNetworkServices() else {
            print("SystemProxy: Failed to get network services")
            return false
        }
        
        // Backup proxy and DNS settings for each network service
        for serviceID in networkServices {
            let proxiesKey = "State:/Network/Service/\(serviceID)/Proxies"
            let dnsKey = "State:/Network/Service/\(serviceID)/DNS"
            
            var serviceSettings: [String: Any] = [:]
            
            if let proxiesDict = SCDynamicStoreCopyValue(dynamicStore, proxiesKey as CFString) as? [String: Any] {
                serviceSettings["Proxies"] = proxiesDict
            }
            
            if let dnsDict = SCDynamicStoreCopyValue(dynamicStore, dnsKey as CFString) as? [String: Any] {
                serviceSettings["DNS"] = dnsDict
            }
            
            if !serviceSettings.isEmpty {
                originalProxySettings[serviceID] = serviceSettings
                print("SystemProxy: Backed up settings for service: \(serviceID)")
            }
        }
        
        return true
    }
    
    private func configureSystemSOCKSProxy() -> Bool {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            print("SystemProxy: Failed to create SCDynamicStore")
            return false
        }
        
        // Get list of network services
        guard let networkServices = getNetworkServices() else {
            print("SystemProxy: Failed to get network services")
            return false
        }
        
        // Configure SOCKS proxy for each network service
        for serviceID in networkServices {
            let proxiesKey = "State:/Network/Service/\(serviceID)/Proxies"
            
            // Get current proxy settings
            var proxiesDict = SCDynamicStoreCopyValue(dynamicStore, proxiesKey as CFString) as? [String: Any] ?? [:]
            
            // Configure SOCKS5 proxy
            proxiesDict["SOCKSEnable"] = 1
            proxiesDict["SOCKSProxy"] = socksProxyHost
            proxiesDict["SOCKSPort"] = socksProxyPort
            
            // Also configure HTTP/HTTPS proxy to route through SOCKS5
            proxiesDict["HTTPEnable"] = 1
            proxiesDict["HTTPProxy"] = socksProxyHost
            proxiesDict["HTTPPort"] = socksProxyPort
            proxiesDict["HTTPSEnable"] = 1
            proxiesDict["HTTPSProxy"] = socksProxyHost
            proxiesDict["HTTPSPort"] = socksProxyPort
            
            // Set the new proxy configuration
            if !SCDynamicStoreSetValue(dynamicStore, proxiesKey as CFString, proxiesDict as CFPropertyList) {
                print("SystemProxy: Failed to set proxy configuration for service: \(serviceID)")
                return false
            }
            
            print("SystemProxy: Configured SOCKS5 proxy for service: \(serviceID)")
        }
        
        return true
    }
    
    private func restoreOriginalProxySettings() -> Bool {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            print("SystemProxy: Failed to create SCDynamicStore")
            return false
        }
        
        // Restore original proxy and DNS settings for each network service
        for (serviceID, originalSettings) in originalProxySettings {
            guard let serviceSettings = originalSettings as? [String: Any] else { continue }
            
            // Restore proxy settings
            if let proxiesDict = serviceSettings["Proxies"] as? [String: Any] {
                let proxiesKey = "State:/Network/Service/\(serviceID)/Proxies"
                if !SCDynamicStoreSetValue(dynamicStore, proxiesKey as CFString, proxiesDict as CFPropertyList) {
                    print("SystemProxy: Failed to restore proxy settings for service: \(serviceID)")
                    return false
                }
            }
            
            print("SystemProxy: Restored settings for service: \(serviceID)")
        }
        
        return true
    }
    
    private func getNetworkServices() -> [String]? {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            return nil
        }
        
        // Get the current network setup
        guard let setupKey = SCDynamicStoreCopyValue(dynamicStore, "Setup:/Network/Global/IPv4" as CFString) as? [String: Any],
              let serviceOrder = setupKey["ServiceOrder"] as? [String] else {
            print("SystemProxy: Failed to get network service order")
            return nil
        }
        
        return serviceOrder
    }
}