//
//  PacketTunnelProvider.swift
//  MyceliumTunnel
//
//  Created by Iwan BK on 07/05/24.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    let mtuSize = 1400
    let addrNetworkPrefixLengths : NSNumber = 64
    let routeDestinationAddress = "400::"
    let routeNetworkPrefixLength : NSNumber = 7

    // TODO:
    // - pass secret key from the options
    // - use completionHandle properly
    // - do logger properly, get rid of NSLog
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        NSLog("myceliumflut startTunnel() called")

        // TODO: add some guard
        let secretKey = options!["secretKey"] as! Data
        let nodeAddr = addressFromSecretKey(data: secretKey)
        
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: nodeAddr)
        tunnelNetworkSettings.ipv6Settings = NEIPv6Settings(addresses: [nodeAddr], networkPrefixLengths: [self.addrNetworkPrefixLengths])
        tunnelNetworkSettings.ipv6Settings?.includedRoutes = [NEIPv6Route(destinationAddress: self.routeDestinationAddress, networkPrefixLength: self.routeNetworkPrefixLength)]
        tunnelNetworkSettings.mtu = NSNumber(integerLiteral: self.mtuSize)
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                NSLog("myceliumflut to set mycelium tunnel network settings: " + error.localizedDescription)
            } else {
                NSLog("myceliumflut tunnel settings set successfully")
            }
            if let tunFd = self?.tunnelFileDescriptor {
                DispatchQueue.global(qos: .default).async {
                    NSLog("myceliumflut startMycelium() should be called with tun fd:%d", tunFd)
                    startMycelium(tunFd: tunFd, secretKey: secretKey)
                }
            } else {
                NSLog("myceliumflut can't get tunFd")
            }
            
            completionHandler(nil)
        }
        
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        NSLog("myceliumflut stopTunnel() called")
        stopMycelium()
        completionHandler()
    }
    
    // TODO: implement this
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        //os_log("iwanbk1 handleAppleMessage...", log: log, type: .info)
        
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    // TODO: implement this
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        //os_log("iwanbk1 sleep...", log: log, type: .info)
        completionHandler()
    }
    
    // TODO: implement this
    override func wake() {
        //os_log("iwanbk1 wake...", log: log, type: .info)
        // Add code here to wake up.
    }
    
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
    
}


