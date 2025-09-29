//
//  PacketTunnelProvider.swift
//  MyceliumTunnel
//
//  Created by Iwan BK on 07/05/24.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    private let mtuSize = 1400
    private let addrNetworkPrefixLengths : NSNumber = 64
    private let routeDestinationAddress = "400::"
    private let routeNetworkPrefixLength : NSNumber = 7

    private var started = false
    private var socksProxyHandler = SOCKSProxyHandler()
    private var isDeviceWideProxyEnabled = false

    // TODO FIXME
    // - use completionHandle properly
    // - how to prevent double start / stop
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        infolog("startTunnel() called")

        // TODO: add some guard
        let peers = options!["peers"] as! [String]
        let secretKey = options!["secretKey"] as! Data
        let nodeAddr = addressFromSecretKey(data: secretKey)
        
        // Check if device-wide proxy mode is requested
        isDeviceWideProxyEnabled = options?["deviceWideProxy"] as? Bool ?? false
        infolog("Device-wide proxy mode: \(isDeviceWideProxyEnabled)")
        
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: nodeAddr)
        tunnelNetworkSettings.ipv6Settings = NEIPv6Settings(addresses: [nodeAddr], networkPrefixLengths: [self.addrNetworkPrefixLengths])
        
        if isDeviceWideProxyEnabled {
            // Configure for device-wide traffic forwarding
            infolog("Configuring tunnel for device-wide proxy mode")
            
            // Route all IPv4 traffic through the tunnel
            tunnelNetworkSettings.ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.1"], subnetMasks: ["255.255.255.0"])
            tunnelNetworkSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
            
            // Route all IPv6 traffic through the tunnel
            tunnelNetworkSettings.ipv6Settings?.includedRoutes = [NEIPv6Route.default()]
            
            // Configure DNS to prevent leaks
            tunnelNetworkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
            tunnelNetworkSettings.dnsSettings?.matchDomains = [""]
            
            // Enable SOCKS proxy handler
            socksProxyHandler.enableDeviceWideMode()
        } else {
            // Standard Mycelium mesh network configuration
            tunnelNetworkSettings.ipv6Settings?.includedRoutes = [NEIPv6Route(destinationAddress: self.routeDestinationAddress, networkPrefixLength: self.routeNetworkPrefixLength)]
        }
        
        tunnelNetworkSettings.mtu = NSNumber(integerLiteral: self.mtuSize)
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                errlog("failed to set tunnel network settings: " + error.localizedDescription)
            } else {
                infolog("tunnel settings set successfully")
            }
            if let tunFd = self?.tunnelFileDescriptor {
                self!.started = true
                
                if self!.isDeviceWideProxyEnabled {
                    // Start packet reading for device-wide proxy mode
                    infolog("Starting packet reading for device-wide proxy mode")
                    self?.startPacketReading()
                    
                    // Still start Mycelium for mesh network functionality
                    DispatchQueue.global(qos: .default).async {
                        infolog("calling startMycelium() for mesh network with tun fd:\(tunFd) and peers = \(peers)")
                        startMycelium(peers: peers, tunFd: tunFd, secretKey: secretKey)
                        if self?.started == true {
                            errlog("mycelium finished unexpectedly")
                            let err = NSError(domain: "tech.threefold.mycelium", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Mycelium finished unexpectedly"])
                            self?.cancelTunnelWithError(err)
                        }
                    }
                } else {
                    // Standard Mycelium mode
                    DispatchQueue.global(qos: .default).async {
                        infolog("calling startMycelium() with tun fd:\(tunFd) and peers = \(peers) ")
                        startMycelium(peers: peers, tunFd: tunFd, secretKey: secretKey)
                        if self?.started == true {
                            errlog("mycelium finished unexpectedly")
                             let err = NSError(domain: "tech.threefold.mycelium", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Mycelium finished unexpectedly"])
                            self?.cancelTunnelWithError(err) // currently no other component will read/receive the err
                        }
                    }
                }
            } else {
                errlog("myceliumflut can't get tunFd")
            }
            
            completionHandler(nil)
        }
        
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        errlog("myceliumflut stopTunnel() called")
        if started {
            // Disable SOCKS proxy handler
            socksProxyHandler.disableDeviceWideMode()
            
            stopMycelium()
            self.started = false
        }

        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app
        infolog("handleAppMessage called")
        
        guard let messageString = String(data: messageData, encoding: .utf8) else {
            errlog("Failed to decode message data")
            completionHandler?(nil)
            return
        }
        
        infolog("Received message: \(messageString)")
        
        if messageString == "getPeerStatus" {
            // Get peer status from mycelium node running in this tunnel
            do {
                let peerStatus = getPeerStatus()
                let responseData = try JSONSerialization.data(withJSONObject: peerStatus, options: [])
                infolog("Returning peer status: \(peerStatus)")
                completionHandler?(responseData)
            } catch {
                errlog("Error getting peer status: \(error.localizedDescription)")
                let errorResponse = ["err_peer_status_error"]
                if let errorData = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                    completionHandler?(errorData)
                } else {
                    completionHandler?(nil)
                }
            }
        } else if messageString == "enableDeviceWideProxy" {
            infolog("Enabling device-wide proxy mode")
            socksProxyHandler.enableDeviceWideMode()
            isDeviceWideProxyEnabled = true
            let response = ["status": "enabled"]
            if let responseData = try? JSONSerialization.data(withJSONObject: response, options: []) {
                completionHandler?(responseData)
            } else {
                completionHandler?(nil)
            }
        } else if messageString == "disableDeviceWideProxy" {
            infolog("Disabling device-wide proxy mode")
            socksProxyHandler.disableDeviceWideMode()
            isDeviceWideProxyEnabled = false
            let response = ["status": "disabled"]
            if let responseData = try? JSONSerialization.data(withJSONObject: response, options: []) {
                completionHandler?(responseData)
            } else {
                completionHandler?(nil)
            }
        } else if messageString == "getProxyStatus" {
            let response = [
                "enabled": isDeviceWideProxyEnabled,
                "socksEnabled": socksProxyHandler.isEnabled
            ]
            if let responseData = try? JSONSerialization.data(withJSONObject: response, options: []) {
                completionHandler?(responseData)
            } else {
                completionHandler?(nil)
            }
        } else {
            errlog("Unknown message: \(messageString)")
            completionHandler?(nil)
        }
    }

    // TODO: implement this
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        errlog("sleep handler")
        completionHandler()
    }
    
    // TODO: implement this
    override func wake() {
        // Add code here to wake up.
        errlog("wake handler should be implemented here")
    }
    
    // taken from wireguard code
    private var tunnelFileDescriptor: Int32? {
        var ctlInfo = ctl_info()
        withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        for fd: Int32 in 0...1024 {
            var addr = sockaddr_ctl()
            var ret: Int32 = -1
            var len = socklen_t(MemoryLayout.size(ofValue: addr))
            withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    ret = getpeername(fd, $0, &len)
                }
            }
            if ret != 0 || addr.sc_family != AF_SYSTEM {
                continue
            }
            if ctlInfo.ctl_id == 0 {
                ret = ioctl(fd, CTLIOCGINFO, &ctlInfo)
                if ret != 0 {
                    continue
                }
            }
            if addr.sc_id == ctlInfo.ctl_id {
                return fd
            }
        }
        return nil
    }
    
    // MARK: - Device-Wide Proxy Packet Handling
    
    private func startPacketReading() {
        infolog("Starting packet reading for device-wide proxy mode")
        readPackets()
    }
    
    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, self.started else { return }
            
            for (index, packet) in packets.enumerated() {
                let protocolNumber = protocols[index].intValue
                
                // Handle packet through SOCKS proxy if enabled
                if self.isDeviceWideProxyEnabled {
                    let handled = self.socksProxyHandler.handlePacket(packet, flow: self.packetFlow)
                    
                    if !handled {
                        // Packet not handled by proxy (e.g., Mycelium mesh traffic)
                        // Let it pass through normally
                        self.packetFlow.writePackets([packet], withProtocols: [protocols[index]])
                    }
                } else {
                    // Standard mode - pass through
                    self.packetFlow.writePackets([packet], withProtocols: [protocols[index]])
                }
            }
            
            // Continue reading packets
            self.readPackets()
        }
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

// TODO: make it in one func with the one in AppDelegate
func mlog(_ msg: String,_ type: OSLogType, _ args: CVarArg...) {
    os_log("%{public}@ %{public}@", log: .default, type: type, "myceliumflut:MyceliumTunnel:", String(describing: msg), args)
}