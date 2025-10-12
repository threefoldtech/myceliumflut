import Cocoa
import FlutterMacOS
import IOKit.ps
import OSLog
import NetworkExtension

class MainFlutterWindow: NSWindow {
    // channel to communicate between flutter & Swift
    private var flutterChannel: FlutterMethodChannel?
    // tunnel status that seen by flutter
    private var flutterTunnelStatus: TunnelStatus = .off
    
    var statusObservationToken: Any? = nil
    
    // tunnel specific variables
    private var vpnManager: NETunnelProviderManager? = nil
    let bundleIdentifier = "tech.threefold.mycelium.MyceliumTunnel"
    let localizedDescription = "mycelium tunnel"
    let vpnUsername = "masterOfMycel"
    let vpnServerAddress = "mycelium"
    

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        // Setup method channel in AppDelegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.setupMethodChannel(with: flutterViewController)
        }
        
        statusObservationToken = observeVPNStatus()
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
    }
    
    func createTunnel(secretKey: Data, peers: [String], tryNum: Int = 0) {
        // tryNum == 1 is a special condition, it happens on very first run after installation.
        // in this case, we can't  use existing vpnManager, we need to do `loadAllFromPreferences`
        // again
        if tryNum != 1 {
            if let vpnManager = self.vpnManager {
                infolog("use existing vpnManager")
                self.startVpnTunnel(vpnManager: vpnManager, secretKey: secretKey, peers: peers)
                return
            }
        }

        NETunnelProviderManager.loadAllFromPreferences { (providers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                errlog("loadAllFromPref failed:" + error.localizedDescription)
                return
            }

            guard let providers = providers else {
                errlog("caught by the nil providers guard")
                return
            } // Handle error if nil

            if providers.count > 0 {
                // TODO : search by bundle identifier
                let myProvider = providers.first(where: { $0.protocolConfiguration?.serverAddress==self.vpnServerAddress })
                if let unwrappedProvider = myProvider { // cek nil
                    self.vpnManager = unwrappedProvider
                    debuglog("use existing provider")
                } else {
                    errlog("provider is null, creating a new one")
                    self.vpnManager = self.createVPN()
                }
            } else {
                infolog("no provider exists, creating a new one")
                self.vpnManager = self.createVPN()
            }
            guard self.vpnManager != nil else {
                errlog("vpnManager is unexpectedly nil")
                self.flutterChannel?.invokeMethod("vpnManager is unexpectedly nil", arguments: nil)
                return
            }
            let vpnManager = self.vpnManager! // it is safe to force it using `!` because of the `guard` above
            
            vpnManager.isEnabled = true
            
            vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    errlog("failed to save self.vpnManager: "+error.localizedDescription)
                } else {
                    infolog("preferences saved successfully")
                    // based on some QnA in the apple developer forums,
                    // very first run (which need to ask for user permission)  will always failed.
                    // The workaround is to retry the process, which we do here.
                    if vpnManager.connection.status == .invalid && tryNum == 0 {
                        infolog("it is on very first run, we need to retry the loadAllFromPreferences")
                        self.createTunnel(secretKey: secretKey, peers: peers, tryNum: 1)
                    } else {
                        self.startVpnTunnel(vpnManager: vpnManager, secretKey: secretKey, peers: peers)
                    }
                }
            })
        }
        
    }
    
    private func startVpnTunnel(vpnManager: NETunnelProviderManager, secretKey: Data, peers: [String]) {
        do {
            let options: [String: NSObject] = [
                "secretKey": secretKey as NSObject,
                "peers": peers as NSObject
            ]
            infolog("calling startVPNTunnel")
            try vpnManager.connection.startVPNTunnel(options: options)
        } catch {
            errlog("startVPNTunnel() failed: " + error.localizedDescription)
        }
    }
    
    @objc func vpnStatusDidChange(_ notification: Notification) {
        if let vpnConnection = notification.object as? NETunnelProviderSession {
            let status = vpnConnection.status
            // Handle the status change
            switch status {
            case .connecting:
                infolog("VPN is connecting")
            case .connected:
                infolog("VPN is connected")
                self.flutterTunnelStatus = .running
                flutterChannel?.invokeMethod("notifyMyceliumStarted", arguments: nil)
            case .disconnecting:
                infolog("VPN is disconnecting")
            case .disconnected:
                infolog("VPN is disconnected.desc:" + notification.description + ". debug desc:" + notification.debugDescription)
                switch self.flutterTunnelStatus {
                case .off:
                    errlog("Unexpected: got .disconnected when flutterTunnelStatus = .off ")
                case .started:
                    // first disconnected, we can ignore it
                    debuglog("first disconnected, we can ignore it")
                case .running:
                    errlog("mycelium failed")
                    flutterChannel?.invokeMethod("notifyMyceliumFailed", arguments: nil)
                case .stopped:
                    flutterChannel?.invokeMethod("notifyMyceliumFinished", arguments: nil)
                    return
                }
            case .invalid:
                infolog("VPN is invalid")
            case .reasserting:
                infolog("VPN is reasserting")
            @unknown default:
                infolog("VPN status is unknown")
            }
        }
    }

    func createVPN() -> NETunnelProviderManager {
        // create protocol configuration
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = self.bundleIdentifier
        providerProtocol.providerConfiguration = [:]
        providerProtocol.serverAddress = self.vpnServerAddress
        providerProtocol.username = self.vpnUsername
        providerProtocol.excludeLocalNetworks = true
        
        providerProtocol.disconnectOnSleep = false
        
        // initialize the manager
        let vpnManager = NETunnelProviderManager()
        vpnManager.protocolConfiguration = providerProtocol
        vpnManager.localizedDescription = self.localizedDescription
        
        return vpnManager
    }
    
    
    func stopMycelium() {
        infolog("stopMycelium")
        self.vpnManager?.connection.stopVPNTunnel()
    }
    
    // MARK: - Tunnel Communication Methods
    
    // Tunnel-based getPeerStatus - communicates directly with tunnel extension (like iOS)
    private var cachedPeerStatus: [String]? = nil
    private var lastPeerStatusCall: Date = Date.distantPast
    private let peerStatusThrottleInterval: TimeInterval = 2.0
    
    // Proxy scanning state
    private var isProxyScanning = false
    private var discoveredProxies: [String] = []
    
    // Generic tunnel message sender for VPN extension communication
    func sendMessageToExtension(message: String, result: @escaping FlutterResult) {
        guard let vpnManager = self.vpnManager else {
            debuglog("VPN manager not available for \(message)")
            result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not available", details: nil))
            return
        }
        
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
            debuglog("Tunnel session not available for \(message)")
            result(FlutterError(code: "NO_TUNNEL_SESSION", message: "Tunnel session not available", details: nil))
            return
        }
        
        // Check if tunnel is connected
        guard session.status == .connected else {
            debuglog("Tunnel not connected (status: \(session.status.rawValue)) for \(message)")
            result(FlutterError(code: "TUNNEL_NOT_CONNECTED", message: "Tunnel not connected", details: nil))
            return
        }
        
        let messageData = message.data(using: .utf8)!
        
        do {
            try session.sendProviderMessage(messageData) { [weak self] responseData in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    guard let responseData = responseData else {
                        debuglog("No response data from tunnel for \(message)")
                        result(FlutterError(code: "NO_TUNNEL_RESPONSE", message: "No response from tunnel", details: nil))
                        return
                    }
                    
                    do {
                        // Try to parse as JSON first (for listProxies)
                        if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String] {
                            result(jsonResponse)
                        } else if let stringResponse = String(data: responseData, encoding: .utf8) {
                            // For simple string responses (like "ok")
                            result([stringResponse])
                        } else {
                            debuglog("Invalid response format from tunnel for \(message)")
                            result(FlutterError(code: "INVALID_TUNNEL_RESPONSE", message: "Invalid response format", details: nil))
                        }
                    } catch {
                        debuglog("Error parsing tunnel response for \(message): \(error.localizedDescription)")
                        result(FlutterError(code: "TUNNEL_PARSE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }
        } catch {
            debuglog("Error sending message to tunnel for \(message): \(error.localizedDescription)")
            result(FlutterError(code: "TUNNEL_MESSAGE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    func getPeerStatusFromService(result: @escaping FlutterResult) {
        let now = Date()
        
        // Throttle requests to prevent excessive calls
        if now.timeIntervalSince(lastPeerStatusCall) < peerStatusThrottleInterval {
            if let cached = cachedPeerStatus {
                debuglog("Returning cached peer status (throttled)")
                result(cached)
                return
            }
        }
        
        lastPeerStatusCall = now
        
        guard let vpnManager = self.vpnManager else {
            debuglog("VPN manager not available, returning cached result or error")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(FlutterError(code: "NO_VPN_MANAGER", message: "VPN manager not available", details: nil))
            }
            return
        }
        
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
            debuglog("Tunnel session not available, returning cached result or error")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(FlutterError(code: "NO_TUNNEL_SESSION", message: "Tunnel session not available", details: nil))
            }
            return
        }
        
        // Check if tunnel is connected
        guard session.status == .connected else {
            debuglog("Tunnel not connected (status: \(session.status.rawValue)), returning cached result or error")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(["err_tunnel_not_connected"])
            }
            return
        }
        
        let messageData = "getPeerStatus".data(using: .utf8)!
        
        do {
            try session.sendProviderMessage(messageData) { [weak self] responseData in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    guard let responseData = responseData else {
                        debuglog("No response data from tunnel, returning cached result or error")
                        if let cached = self.cachedPeerStatus {
                            result(cached)
                        } else {
                            result(["err_no_tunnel_response"])
                        }
                        return
                    }
                    
                    do {
                        if let peerStatus = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String] {
                            self.cachedPeerStatus = peerStatus
                            result(peerStatus)
                        } else {
                            if let cached = self.cachedPeerStatus {
                                result(cached)
                            } else {
                                result(["err_invalid_tunnel_response"])
                            }
                        }
                    } catch {
                        debuglog("Error parsing tunnel response: \(error.localizedDescription)")
                        if let cached = self.cachedPeerStatus {
                            result(cached)
                        } else {
                            result(["err_tunnel_parse_error"])
                        }
                    }
                }
            }
        } catch {
            debuglog("Error sending message to tunnel: \(error.localizedDescription)")
            if let cached = cachedPeerStatus {
                result(cached)
            } else {
                result(FlutterError(code: "TUNNEL_MESSAGE_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    func observeVPNStatus() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: OperationQueue.main) { [weak self] notification in
            self?.vpnStatusDidChange(notification)
        }
    }
}

enum TunnelStatus {
    case off
    case started
    case running
    case stopped
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

extension MainFlutterWindow {
    // MARK: - Main App Proxy Scanner
    
    func startProxyProbeInMainApp(result: @escaping FlutterResult) {
        print("🔍 macOS: Starting proxy probe in main app (can reach overlay network)")
        infolog("Starting proxy probe in main app (can reach overlay network)")
        self.isProxyScanning = true
        self.discoveredProxies = []
        
        // Get peer status to find overlay addresses
        self.getPeerStatusFromService { peerStatusResult in
            print("🔍 macOS: Got peer status result: \(type(of: peerStatusResult))")
            
            guard let peerStatus = peerStatusResult as? [String], peerStatus.count > 1 else {
                print("❌ macOS: No peers found or invalid peer status")
                result(["err_no_peers"])
                return
            }
            
            print("🔍 macOS: Peer status has \(peerStatus.count) entries")
            
            // Parse overlay addresses from peer status (JSON format)
            var overlayAddresses: [String] = []
            for i in 1..<peerStatus.count {
                let peerJson = peerStatus[i]
                print("🔍 macOS: Parsing peer \(i): \(peerJson)")
                
                // Parse JSON to extract overlay address
                if let jsonData = peerJson.data(using: .utf8),
                   let peerDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let address = peerDict["address"] as? String {
                    
                    // Extract IP from "IP:PORT" format
                    let ipPart = address.split(separator: ":").first.map(String.init) ?? ""
                    
                    // Check if it's an IPv6 overlay address (starts with 4 or 5)
                    if ipPart.hasPrefix("4") || ipPart.hasPrefix("5") {
                        overlayAddresses.append(ipPart)
                        print("🔍 macOS: Added overlay address: \(ipPart)")
                    } else {
                        print("⚠️ macOS: Skipping non-overlay address: \(ipPart)")
                    }
                } else {
                    print("❌ macOS: Failed to parse JSON for peer \(i)")
                }
            }
            
            print("🔍 macOS: Probing \(overlayAddresses.count) overlay addresses for SOCKS5 proxies")
            infolog("Probing \(overlayAddresses.count) overlay addresses for SOCKS5 proxies")
            
            // Probe each address in parallel
            let group = DispatchGroup()
            for address in overlayAddresses {
                guard self.isProxyScanning else { break }
                
                group.enter()
                self.testSocks5Proxy(address: address) { isValid in
                    if isValid {
                        let proxyAddr = "[\(address)]:1080"
                        self.discoveredProxies.append(proxyAddr)
                        infolog("✅ Found valid proxy: \(proxyAddr)")
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                infolog("Proxy probe complete. Found \(self.discoveredProxies.count) proxies")
                result(["ok"])
            }
        }
    }
    
    private func testSocks5Proxy(address: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            print("🔎 macOS: Testing SOCKS5 proxy at [\(address)]:1080")
            
            var inputStream: InputStream?
            var outputStream: OutputStream?
            
            // Try to connect to [address]:1080
            Stream.getStreamsToHost(withName: address, port: 1080, inputStream: &inputStream, outputStream: &outputStream)
            
            guard let input = inputStream, let output = outputStream else {
                print("❌ macOS: Failed to create streams for \(address)")
                completion(false)
                return
            }
            
            print("✅ macOS: Created streams for \(address), opening...")
            
            input.open()
            output.open()
            
            // Send SOCKS5 greeting
            let greeting: [UInt8] = [0x05, 0x01, 0x00]
            let written = output.write(greeting, maxLength: greeting.count)
            
            guard written == greeting.count else {
                print("❌ macOS: Failed to write SOCKS5 greeting to \(address)")
                input.close()
                output.close()
                completion(false)
                return
            }
            
            print("✅ macOS: Sent SOCKS5 greeting to \(address), waiting for response...")
            
            // Read response with timeout
            var response = [UInt8](repeating: 0, count: 2)
            var totalRead = 0
            let timeout = Date().addingTimeInterval(2.0)
            
            while totalRead < 2 && Date() < timeout {
                if input.hasBytesAvailable {
                    let read = input.read(&response[totalRead], maxLength: 2 - totalRead)
                    if read > 0 {
                        totalRead += read
                    }
                }
                usleep(10000) // 10ms
            }
            
            input.close()
            output.close()
            
            // Check if valid SOCKS5 response
            let isValid = totalRead == 2 && response[0] == 0x05 && response[1] == 0x00
            
            if isValid {
                print("✅ macOS: Valid SOCKS5 proxy found at [\(address)]:1080")
            } else {
                print("❌ macOS: Invalid or no response from \(address) (read \(totalRead) bytes)")
            }
            
            completion(isValid)
        }
    }
}

func mlog(_ msg: String,_ type: OSLogType, _ args: CVarArg...) {
    os_log("%{public}@ %{public}@", log: .default, type: type, "myceliumflut:MainFlutterWindow:", String(describing: msg), args)
}



// NotificationToken and NotificationCenter was taken from https://oleb.net/blog/2018/01/notificationcenter-removeobserver/
final class NotificationToken {
    let notificationCenter: NotificationCenter
    let token: Any

    init(notificationCenter: NotificationCenter = .default, token: Any) {
        self.notificationCenter = notificationCenter
        self.token = token
    }

    deinit {
        notificationCenter.removeObserver(token)
    }
}

extension NotificationCenter {
    /// Convenience wrapper for addObserver(forName:object:queue:using:)
    /// that returns our custom `NotificationToken`.
    func observe(name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NotificationToken {
        let token = addObserver(forName: name, object: obj, queue: queue, using: block)
        return NotificationToken(notificationCenter: self, token: token)
    }
}