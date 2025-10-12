//
//  PacketTunnelProvider.swift
//  MyceliumTunnel
//
//  Created by Iwan BK on 01/09/24.
//

import NetworkExtension
import OSLog
import Foundation
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    private let mtuSize = 1400
    private let addrNetworkPrefixLengths : NSNumber = 64
    private let routeDestinationAddress = "400::"
    private let routeNetworkPrefixLength : NSNumber = 7

    private var started = false
    
    override init() {
        infolog("INIT PacketTunnelProvider")
        super.init()
    }

    // TODO FIXME
    // - use completionHandle properly
    // - how to prevent double start / stop
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        infolog("startTunnel called")
        
        // TODO: add some guard
        let peers = options!["peers"] as! [String]
        let secretKey = options!["secretKey"] as! Data
        let nodeAddr = addressFromSecretKey(data: secretKey)
        
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: nodeAddr)
        tunnelNetworkSettings.ipv6Settings = NEIPv6Settings(addresses: [nodeAddr], networkPrefixLengths: [self.addrNetworkPrefixLengths])
        
        // Route overlay network (400::/7) through this VPN tunnel interface for HOST traffic
        // But allow the extension itself to bypass this routing
        let overlayRoute = NEIPv6Route(destinationAddress: self.routeDestinationAddress, networkPrefixLength: self.routeNetworkPrefixLength)
        tunnelNetworkSettings.ipv6Settings?.includedRoutes = [overlayRoute]
        
        // CRITICAL: Allow extension's own traffic to bypass the tunnel
        // This lets Mycelium (running in extension) connect to overlay addresses directly via TUN
        tunnelNetworkSettings.ipv6Settings?.excludedRoutes = []
        
        tunnelNetworkSettings.mtu = NSNumber(integerLiteral: self.mtuSize)
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                errlog("failed to set tunnel network settings: " + error.localizedDescription)
            } else {
                infolog("tunnel settings set successfully")
            }
            if let tunFd = self?.tunnelFileDescriptor {
                self!.started = true
                
                // Start packet forwarding between packetFlow and TUN fd
                self?.startPacketForwarding(tunFd: tunFd)
                
                DispatchQueue.global(qos: .default).async {
                    infolog("calling startMycelium()  with tun fd:\(tunFd) and peers = \(peers) ")
                    startMycelium(peers: peers, tunFd: tunFd, secretKey: secretKey)
                    if self?.started == true {
                        errlog("mycelium finished unexpectedly")
                         let err = NSError(domain: "tech.threefold.mycelium", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Mycelium finished unexpectedly"])
                        self?.cancelTunnelWithError(err) // currently no other component will read/receive the err
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
            stopMycelium()
            self.started = false
        }

        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app
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
                // Return error as JSON array
                do {
                    let errorResponse = ["err_peer_status_failed"]
                    let errorData = try JSONSerialization.data(withJSONObject: errorResponse, options: [])
                    completionHandler?(errorData)
                } catch {
                    completionHandler?(nil)
                }
            }
        } else if messageString.hasPrefix("proxyConnect:") {
            // Extract remote address from message
            let remote = String(messageString.dropFirst("proxyConnect:".count))
            infolog("Proxy connect to: \(remote)")
            do {
                let result = proxyConnect(remote: remote)
                let responseData = try JSONSerialization.data(withJSONObject: result, options: [])
                completionHandler?(responseData)
            } catch {
                errlog("Error in proxyConnect: \(error.localizedDescription)")
                let errorResponse = ["err_proxy_connect_failed"]
                if let errorData = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                    completionHandler?(errorData)
                } else {
                    completionHandler?(nil)
                }
            }
        } else if messageString == "proxyDisconnect" {
            infolog("Proxy disconnect")
            do {
                let result = proxyDisconnect()
                let responseData = try JSONSerialization.data(withJSONObject: result, options: [])
                completionHandler?(responseData)
            } catch {
                errlog("Error in proxyDisconnect: \(error.localizedDescription)")
                let errorResponse = ["err_proxy_disconnect_failed"]
                if let errorData = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                    completionHandler?(errorData)
                } else {
                    completionHandler?(nil)
                }
            }
        } else if messageString == "startProxyProbe" {
            infolog("Start proxy probe")
            do {
                let result = startProxyProbe()
                let responseData = try JSONSerialization.data(withJSONObject: result, options: [])
                completionHandler?(responseData)
            } catch {
                errlog("Error in startProxyProbe: \(error.localizedDescription)")
                let errorResponse = ["err_start_proxy_probe_failed"]
                if let errorData = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                    completionHandler?(errorData)
                } else {
                    completionHandler?(nil)
                }
            }
        } else if messageString == "stopProxyProbe" {
            infolog("Stop proxy probe")
            do {
                let result = stopProxyProbe()
                let responseData = try JSONSerialization.data(withJSONObject: result, options: [])
                completionHandler?(responseData)
            } catch {
                errlog("Error in stopProxyProbe: \(error.localizedDescription)")
                let errorResponse = ["err_stop_proxy_probe_failed"]
                if let errorData = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                    completionHandler?(errorData)
                } else {
                    completionHandler?(nil)
                }
            }
        } else if messageString == "listProxies" {
            infolog("List proxies")
            do {
                let result = listProxies()
                let responseData = try JSONSerialization.data(withJSONObject: result, options: [])
                completionHandler?(responseData)
            } catch {
                errlog("Error in listProxies: \(error.localizedDescription)")
                let errorResponse = ["err_list_proxies_failed"]
                if let errorData = try? JSONSerialization.data(withJSONObject: errorResponse, options: []) {
                    completionHandler?(errorData)
                } else {
                    completionHandler?(nil)
                }
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
    
    // Forward packets between NEPacketTunnelFlow and TUN file descriptor
    private func startPacketForwarding(tunFd: Int32) {
        infolog("Starting packet forwarding for TUN fd: \(tunFd)")
        
        // Read packets from packetFlow and write to TUN
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, self.started else { return }
            
            for packet in packets {
                packet.withUnsafeBytes { buffer in
                    let ptr = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    _ = write(tunFd, ptr, buffer.count)
                }
            }
            
            // Continue reading
            self.startPacketForwarding(tunFd: tunFd)
        }
        
        // Read from TUN and write to packetFlow (in background)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            
            while self?.started == true {
                let bytesRead = read(tunFd, &buffer, buffer.count)
                
                if bytesRead > 0 {
                    let data = Data(bytes: buffer, count: bytesRead)
                    let packets = [data]
                    let protocols = [NSNumber(value: AF_INET6)]
                    
                    self?.packetFlow.writePackets(packets, withProtocols: protocols)
                } else if bytesRead < 0 {
                    let error = String(cString: strerror(errno))
                    errlog("Error reading from TUN: \(error)")
                    break
                }
            }
            
            infolog("Packet forwarding stopped")
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
