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
    private var socksProxyHost = "127.0.0.1"
    private var socksProxyPort = 1080
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
                if let arguments = call.arguments as? [String: Any],
                   let proxyAddress = arguments["proxyAddress"] as? String {
                    self.enableDeviceWideProxy(proxyAddress: proxyAddress, result: result)
                } else {
                    self.enableDeviceWideProxy(proxyAddress: nil, result: result)
                }
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
    
    // MARK: - Proxy Methods
    
    private func handleProxyConnect(remote: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let connectResult = proxyConnect(remote: remote)
            DispatchQueue.main.async {
                result(connectResult)
            }
        }
    }
    
    private func handleProxyDisconnect(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let disconnectResult = proxyDisconnect()
            DispatchQueue.main.async {
                result(disconnectResult)
            }
        }
    }
    
    private func handleStartProxyProbe(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let probeResult = startProxyProbe()
            DispatchQueue.main.async {
                result(probeResult)
            }
        }
    }
    
    private func handleStopProxyProbe(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let stopResult = stopProxyProbe()
            DispatchQueue.main.async {
                result(stopResult)
            }
        }
    }
    
    private func handleListProxies(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let proxies = listProxies()
            DispatchQueue.main.async {
                result(proxies)
            }
        }
    }
    
    // MARK: - Device-Wide Proxy Methods
    
    private func updateProxyAddress(_ proxyAddress: String) {
        print("macOS: Updating proxy address to: \(proxyAddress)")
        
        // Parse proxy address like "[410:2778:53bf:6f41:af28:1b60:d7c0:707a]:1080"
        if proxyAddress.hasPrefix("[") && proxyAddress.contains("]:") {
            // IPv6 format
            let components = proxyAddress.components(separatedBy: "]:")
            if components.count == 2 {
                let ipv6Address = String(components[0].dropFirst()) // Remove leading "["
                if let port = Int(components[1]) {
                    socksProxyHost = ipv6Address
                    socksProxyPort = port
                    print("macOS: Set proxy to IPv6: [\(socksProxyHost)]:\(socksProxyPort)")
                }
            }
        } else if proxyAddress.contains(":") {
            // IPv4 format
            let components = proxyAddress.components(separatedBy: ":")
            if components.count == 2 {
                socksProxyHost = components[0]
                if let port = Int(components[1]) {
                    socksProxyPort = port
                    print("macOS: Set proxy to IPv4: \(socksProxyHost):\(socksProxyPort)")
                }
            }
        }
    }
    
    func enableDeviceWideProxy(proxyAddress: String?, result: @escaping FlutterResult) {
        print("macOS: Enabling device-wide SOCKS5 proxy")
        
        DispatchQueue.global(qos: .background).async {
            // Update proxy address if provided
            if let address = proxyAddress {
                self.updateProxyAddress(address)
            }
            
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
    
    func disableDeviceWideProxy(result: @escaping FlutterResult) {
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
    
    func getProxyStatus(result: @escaping FlutterResult) {
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
    
    // MARK: - Application Lifecycle
    
    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Clean up proxy settings before terminating
        if isProxyEnabled {
            _ = disableSystemProxy()
        }
        
        // Stop Mycelium service
        if isMyceliumRunning {
            myceliumStartTask?.cancel()
        }
        
        let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        return _windowManager.applicationShouldTerminate(controller);
    }
    
    // MARK: - System Proxy Implementation
    
    private func enableSystemProxy() -> Bool {
        print("SystemProxy: Enabling device-wide SOCKS5 proxy...")
        print("SystemProxy: Will configure system to use SOCKS5 proxy at \(socksProxyHost):\(socksProxyPort)")
        
        // Try without admin privileges first
        print("SystemProxy: Attempting to configure proxy without admin privileges...")
        
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
        print("SystemProxy: Device-wide SOCKS5 proxy enabled successfully (no admin required)")
        print("SystemProxy: System should now route traffic through \(socksProxyHost):\(socksProxyPort)")
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
        print("SystemProxy: Using networksetup command for proxy configuration")
        
        // Use networksetup command which is more reliable
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        
        // First, get list of network services
        task.arguments = ["-listallnetworkservices"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let services = output.components(separatedBy: .newlines).filter { !$0.isEmpty && !$0.hasPrefix("An asterisk") }
            
            var successCount = 0
            
            for service in services {
                let trimmedService = service.trimmingCharacters(in: .whitespaces)
                if trimmedService.isEmpty { continue }
                
                // Configure SOCKS proxy for this service
                let socksTask = Process()
                socksTask.launchPath = "/usr/sbin/networksetup"
                socksTask.arguments = ["-setsocksfirewallproxy", trimmedService, socksProxyHost, String(socksProxyPort)]
                
                do {
                    try socksTask.run()
                    socksTask.waitUntilExit()
                    
                    if socksTask.terminationStatus == 0 {
                        print("SystemProxy: Configured SOCKS proxy for service: \(trimmedService)")
                        successCount += 1
                    } else {
                        print("SystemProxy: Failed to configure SOCKS proxy for service: \(trimmedService)")
                    }
                } catch {
                    print("SystemProxy: Error configuring SOCKS proxy for service \(trimmedService): \(error)")
                }
            }
            
            print("SystemProxy: Successfully configured \(successCount)/\(services.count) network services")
            return successCount > 0
            
        } catch {
            print("SystemProxy: Failed to get network services: \(error)")
            return false
        }
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