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
        
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: nodeAddr)
        tunnelNetworkSettings.ipv6Settings = NEIPv6Settings(addresses: [nodeAddr], networkPrefixLengths: [self.addrNetworkPrefixLengths])
        tunnelNetworkSettings.ipv6Settings?.includedRoutes = [NEIPv6Route(destinationAddress: self.routeDestinationAddress, networkPrefixLength: self.routeNetworkPrefixLength)]
        tunnelNetworkSettings.mtu = NSNumber(integerLiteral: self.mtuSize)
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                errlog("failed to set tunnel network settings: " + error.localizedDescription)
            } else {
                infolog("tunnel settings set successfully")
            }
            if let tunFd = self?.tunnelFileDescriptor {
                self!.started = true
                DispatchQueue.global(qos: .default).async {
                    infolog("calling startMycelium()  with tun fd:\(tunFd) and peers = \(peers) ")
                    startMycelium(peers: peers, tunFd: tunFd, secretKey: secretKey)
                    if self?.started == true {
                        errlog("mycelium finished unexpectedly")
                    }
                    // TODO we currently can't handle failed mycelium properly
                    // see https://github.com/threefoldtech/myceliumflut/issues/35
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
    
    // TODO: implement this
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        errlog("handleAppMessage handler")
        
        if let handler = completionHandler {
            handler(messageData)
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
