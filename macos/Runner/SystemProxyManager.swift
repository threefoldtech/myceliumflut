import Foundation
import SystemConfiguration
import OSLog

/// Manages macOS system proxy settings for device-wide traffic forwarding
class SystemProxyManager {
    private let socksProxyHost = "127.0.0.1"
    private let socksProxyPort = 1080
    private var originalProxySettings: [String: Any] = [:]
    private var isProxyEnabled = false
    
    /// Enable device-wide SOCKS5 proxy by configuring system network settings
    func enableDeviceWideProxy() -> Bool {
        infolog("SystemProxyManager: Enabling device-wide SOCKS5 proxy...")
        
        // First, backup current proxy settings
        guard backupCurrentProxySettings() else {
            errlog("SystemProxyManager: Failed to backup current proxy settings")
            return false
        }
        
        // Configure system to use SOCKS5 proxy
        guard configureSystemSOCKSProxy() else {
            errlog("SystemProxyManager: Failed to configure SOCKS5 proxy")
            return false
        }
        
        isProxyEnabled = true
        infolog("SystemProxyManager: Device-wide SOCKS5 proxy enabled successfully")
        return true
    }
    
    /// Disable device-wide proxy by restoring original system settings
    func disableDeviceWideProxy() -> Bool {
        infolog("SystemProxyManager: Disabling device-wide SOCKS5 proxy...")
        
        guard isProxyEnabled else {
            infolog("SystemProxyManager: Proxy is not currently enabled")
            return true
        }
        
        guard restoreOriginalProxySettings() else {
            errlog("SystemProxyManager: Failed to restore original proxy settings")
            return false
        }
        
        isProxyEnabled = false
        originalProxySettings.removeAll()
        infolog("SystemProxyManager: Device-wide SOCKS5 proxy disabled successfully")
        return true
    }
    
    /// Get current proxy status
    func getProxyStatus() -> [String: Any] {
        return [
            "enabled": isProxyEnabled,
            "host": socksProxyHost,
            "port": socksProxyPort,
            "type": "SOCKS5"
        ]
    }
    
    // MARK: - Private Methods
    
    private func backupCurrentProxySettings() -> Bool {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            errlog("SystemProxyManager: Failed to create SCDynamicStore")
            return false
        }
        
        // Get list of network services
        guard let networkServices = getNetworkServices() else {
            errlog("SystemProxyManager: Failed to get network services")
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
                infolog("SystemProxyManager: Backed up settings for service: \(serviceID)")
            }
        }
        
        return true
    }
    
    private func configureSystemSOCKSProxy() -> Bool {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            errlog("SystemProxyManager: Failed to create SCDynamicStore")
            return false
        }
        
        // Get list of network services
        guard let networkServices = getNetworkServices() else {
            errlog("SystemProxyManager: Failed to get network services")
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
            
            // Configure DNS to prevent leaks
            configureDNSSettings(for: serviceID)
            
            // Set the new proxy configuration
            if !SCDynamicStoreSetValue(dynamicStore, proxiesKey as CFString, proxiesDict as CFPropertyList) {
                errlog("SystemProxyManager: Failed to set proxy configuration for service: \(serviceID)")
                return false
            }
            
            infolog("SystemProxyManager: Configured SOCKS5 proxy for service: \(serviceID)")
        }
        
        return true
    }
    
    private func restoreOriginalProxySettings() -> Bool {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            errlog("SystemProxyManager: Failed to create SCDynamicStore")
            return false
        }
        
        // Restore original proxy and DNS settings for each network service
        for (serviceID, originalSettings) in originalProxySettings {
            guard let serviceSettings = originalSettings as? [String: Any] else { continue }
            
            // Restore proxy settings
            if let proxiesDict = serviceSettings["Proxies"] as? [String: Any] {
                let proxiesKey = "State:/Network/Service/\(serviceID)/Proxies"
                if !SCDynamicStoreSetValue(dynamicStore, proxiesKey as CFString, proxiesDict as CFPropertyList) {
                    errlog("SystemProxyManager: Failed to restore proxy settings for service: \(serviceID)")
                    return false
                }
            }
            
            // Restore DNS settings
            restoreDNSSettings(for: serviceID, originalSettings: serviceSettings)
            
            infolog("SystemProxyManager: Restored settings for service: \(serviceID)")
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
            errlog("SystemProxyManager: Failed to get network service order")
            return nil
        }
        
        return serviceOrder
    }
}

/// Extension for handling proxy exceptions and advanced configuration
extension SystemProxyManager {
    
    /// Configure proxy exceptions for Mycelium mesh traffic
    private func configureProxyExceptions() -> Bool {
        // Add exceptions for Mycelium peer connections (port 9651)
        // This ensures mesh network traffic bypasses the proxy
        
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            return false
        }
        
        guard let networkServices = getNetworkServices() else {
            return false
        }
        
        for serviceID in networkServices {
            let proxiesKey = "State:/Network/Service/\(serviceID)/Proxies"
            
            if var proxiesDict = SCDynamicStoreCopyValue(dynamicStore, proxiesKey as CFString) as? [String: Any] {
                // Add proxy bypass rules for Mycelium mesh network
                var exceptionList = proxiesDict["ExceptionsList"] as? [String] ?? []
                
                // Add localhost and Mycelium-specific exceptions
                let myceliumExceptions = [
                    "127.0.0.1",
                    "localhost",
                    "*.local",
                    "*:9651"  // Mycelium mesh port
                ]
                
                for exception in myceliumExceptions {
                    if !exceptionList.contains(exception) {
                        exceptionList.append(exception)
                    }
                }
                
                proxiesDict["ExceptionsList"] = exceptionList
                
                if !SCDynamicStoreSetValue(dynamicStore, proxiesKey as CFString, proxiesDict as CFPropertyList) {
                    errlog("SystemProxyManager: Failed to set proxy exceptions for service: \(serviceID)")
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Check if SOCKS5 proxy is reachable
    func isSOCKSProxyReachable() -> Bool {
        let host = CFHostCreateWithName(nil, socksProxyHost as CFString).takeRetainedValue()
        var reachable = false
        
        CFHostStartInfoResolution(host, .addresses, nil)
        
        var resolved: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue() as? [Data] {
            reachable = !addresses.isEmpty && resolved.boolValue
        }
        
        return reachable
    }
    
    /// Configure DNS settings to prevent DNS leaks
    private func configureDNSSettings(for serviceID: String) {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            return
        }
        
        let dnsKey = "State:/Network/Service/\(serviceID)/DNS"
        
        // Get current DNS settings
        var dnsDict = SCDynamicStoreCopyValue(dynamicStore, dnsKey as CFString) as? [String: Any] ?? [:]
        
        // Configure DNS servers that work well with SOCKS5
        // Using public DNS servers to prevent local DNS leaks
        dnsDict["ServerAddresses"] = [
            "8.8.8.8",      // Google DNS
            "8.8.4.4",      // Google DNS
            "1.1.1.1",      // Cloudflare DNS
            "1.0.0.1"       // Cloudflare DNS
        ]
        
        // Set search domains to empty to prevent local domain leaks
        dnsDict["SearchDomains"] = []
        
        // Set the DNS configuration
        if !SCDynamicStoreSetValue(dynamicStore, dnsKey as CFString, dnsDict as CFPropertyList) {
            errlog("SystemProxyManager: Failed to set DNS configuration for service: \(serviceID)")
        } else {
            infolog("SystemProxyManager: Configured DNS settings for service: \(serviceID)")
        }
    }
    
    /// Restore original DNS settings
    private func restoreDNSSettings(for serviceID: String, originalSettings: [String: Any]) {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MyceliumProxyManager" as CFString, nil, nil) else {
            return
        }
        
        let dnsKey = "State:/Network/Service/\(serviceID)/DNS"
        
        // Restore original DNS settings if they existed
        if let originalDNS = originalSettings["DNS"] as? [String: Any] {
            if !SCDynamicStoreSetValue(dynamicStore, dnsKey as CFString, originalDNS as CFPropertyList) {
                errlog("SystemProxyManager: Failed to restore DNS settings for service: \(serviceID)")
            } else {
                infolog("SystemProxyManager: Restored DNS settings for service: \(serviceID)")
            }
        }
    }
}

// MARK: - Logging Functions
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
    os_log("%{public}@ %{public}@", log: .default, type: type, "myceliumflut:SystemProxyManager:", String(describing: msg), args)
}
