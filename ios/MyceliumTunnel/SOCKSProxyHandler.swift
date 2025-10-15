import Foundation
import Network
import NetworkExtension
import OSLog

/// Handles SOCKS5 proxy connections for device-wide traffic forwarding
class SOCKSProxyHandler {
    private let socksProxyHost = "127.0.0.1"
    private let socksProxyPort: UInt16 = 1080
    private var isDeviceWideMode = false
    private var activeConnections: [NWConnection] = []
    private let connectionQueue = DispatchQueue(label: "socks.proxy.connections", qos: .userInitiated)
    
    /// Enable device-wide proxy mode
    func enableDeviceWideMode() {
        infolog("SOCKSProxyHandler: Enabling device-wide proxy mode")
        isDeviceWideMode = true
    }
    
    /// Disable device-wide proxy mode
    func disableDeviceWideMode() {
        infolog("SOCKSProxyHandler: Disabling device-wide proxy mode")
        isDeviceWideMode = false
        closeAllConnections()
    }
    
    /// Check if device-wide mode is enabled
    var isEnabled: Bool {
        return isDeviceWideMode
    }
    
    /// Handle packet and forward through SOCKS5 proxy if needed
    func handlePacket(_ packet: Data, flow: NEPacketTunnelFlow) -> Bool {
        guard isDeviceWideMode else {
            return false // Let normal Mycelium handling take over
        }
        
        // Parse packet to determine if it should be proxied
        guard let (destinationHost, destinationPort, protocolType) = parsePacket(packet) else {
            return false
        }
        
        // Check if this traffic should bypass proxy (Mycelium mesh traffic)
        if shouldBypassProxy(host: destinationHost, port: destinationPort) {
            return false // Let normal Mycelium handling take over
        }
        
        // Forward through SOCKS5 proxy
        forwardThroughSOCKS(
            packet: packet,
            destinationHost: destinationHost,
            destinationPort: destinationPort,
            protocolType: protocolType,
            flow: flow
        )
        
        return true // Packet handled by proxy
    }
    
    // MARK: - Private Methods
    
    private func parsePacket(_ packet: Data) -> (host: String, port: UInt16, protocol: String)? {
        guard packet.count >= 20 else { return nil } // Minimum IPv4 header size
        
        // Parse IPv4 header
        let versionAndHeaderLength = packet[0]
        let version = (versionAndHeaderLength & 0xF0) >> 4
        
        guard version == 4 else {
            // Handle IPv6 if needed
            return parseIPv6Packet(packet)
        }
        
        let headerLength = Int(versionAndHeaderLength & 0x0F) * 4
        guard packet.count >= headerLength + 8 else { return nil } // Need TCP/UDP header
        
        let protocolByte = packet[9]
        let protocolString = protocolByte == 6 ? "TCP" : (protocolByte == 17 ? "UDP" : "OTHER")
        
        // Extract destination IP
        let destIPBytes = packet.subdata(in: 16..<20)
        let destIP = destIPBytes.map { String($0) }.joined(separator: ".")
        
        // Extract destination port (from TCP/UDP header)
        let portBytes = packet.subdata(in: headerLength+2..<headerLength+4)
        let destPort = UInt16(portBytes[0]) << 8 | UInt16(portBytes[1])
        
        return (host: destIP, port: destPort, protocol: protocolString)
    }
    
    private func parseIPv6Packet(_ packet: Data) -> (host: String, port: UInt16, protocol: String)? {
        guard packet.count >= 40 else { return nil } // IPv6 header size
        
        let nextHeader = packet[6]
        let protocolString = nextHeader == 6 ? "TCP" : (nextHeader == 17 ? "UDP" : "OTHER")
        
        // Extract IPv6 destination address
        let destIPBytes = packet.subdata(in: 24..<40)
        var destIP = ""
        for i in stride(from: 0, to: 16, by: 2) {
            if i > 0 { destIP += ":" }
            let value = UInt16(destIPBytes[i]) << 8 | UInt16(destIPBytes[i+1])
            destIP += String(format: "%x", value)
        }
        
        // Extract destination port (assuming TCP/UDP follows immediately)
        guard packet.count >= 44 else { return nil }
        let portBytes = packet.subdata(in: 42..<44)
        let destPort = UInt16(portBytes[0]) << 8 | UInt16(portBytes[1])
        
        return (host: destIP, port: destPort, protocol: protocolString)
    }
    
    private func shouldBypassProxy(host: String, port: UInt16) -> Bool {
        // Bypass proxy for:
        // 1. Mycelium mesh traffic (port 9651)
        // 2. Local traffic
        // 3. SOCKS proxy itself
        
        if port == 9651 {
            infolog("SOCKSProxyHandler: Bypassing proxy for Mycelium mesh traffic: \(host):\(port)")
            return true
        }
        
        if host == "127.0.0.1" || host == "localhost" || host.hasPrefix("192.168.") || host.hasPrefix("10.") {
            return true
        }
        
        if host == socksProxyHost && port == socksProxyPort {
            return true
        }
        
        return false
    }
    
    private func forwardThroughSOCKS(
        packet: Data,
        destinationHost: String,
        destinationPort: UInt16,
        protocolType: String,
        flow: NEPacketTunnelFlow
    ) {
        infolog("SOCKSProxyHandler: Forwarding \(protocolType) traffic to \(destinationHost):\(destinationPort) through SOCKS5")
        
        connectionQueue.async {
            self.createSOCKSConnection(
                destinationHost: destinationHost,
                destinationPort: destinationPort,
                originalPacket: packet,
                flow: flow
            )
        }
    }
    
    private func createSOCKSConnection(
        destinationHost: String,
        destinationPort: UInt16,
        originalPacket: Data,
        flow: NEPacketTunnelFlow
    ) {
        // Create connection to SOCKS5 proxy
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(socksProxyHost),
            port: NWEndpoint.Port(integerLiteral: socksProxyPort)
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        activeConnections.append(connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                infolog("SOCKSProxyHandler: Connected to SOCKS5 proxy")
                self?.performSOCKSHandshake(
                    connection: connection,
                    destinationHost: destinationHost,
                    destinationPort: destinationPort,
                    originalPacket: originalPacket,
                    flow: flow
                )
            case .failed(let error):
                errlog("SOCKSProxyHandler: Connection to SOCKS5 proxy failed: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                infolog("SOCKSProxyHandler: Connection to SOCKS5 proxy cancelled")
                self?.removeConnection(connection)
            default:
                break
            }
        }
        
        connection.start(queue: connectionQueue)
    }
    
    private func performSOCKSHandshake(
        connection: NWConnection,
        destinationHost: String,
        destinationPort: UInt16,
        originalPacket: Data,
        flow: NEPacketTunnelFlow
    ) {
        // SOCKS5 handshake: version, number of methods, method (no auth)
        let handshake = Data([0x05, 0x01, 0x00])
        
        connection.send(content: handshake, completion: .contentProcessed { error in
            if let error = error {
                errlog("SOCKSProxyHandler: Failed to send SOCKS5 handshake: \(error)")
                return
            }
            
            // Read handshake response
            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, isComplete, error in
                guard let data = data, data.count == 2, data[0] == 0x05, data[1] == 0x00 else {
                    errlog("SOCKSProxyHandler: Invalid SOCKS5 handshake response")
                    return
                }
                
                // Send connection request
                self.sendSOCKSConnectionRequest(
                    connection: connection,
                    destinationHost: destinationHost,
                    destinationPort: destinationPort,
                    originalPacket: originalPacket,
                    flow: flow
                )
            }
        })
    }
    
    private func sendSOCKSConnectionRequest(
        connection: NWConnection,
        destinationHost: String,
        destinationPort: UInt16,
        originalPacket: Data,
        flow: NEPacketTunnelFlow
    ) {
        // SOCKS5 connection request: version, command (connect), reserved, address type
        var request = Data([0x05, 0x01, 0x00])
        
        // Add destination address
        if let ipv4 = IPv4Address(destinationHost) {
            request.append(0x01) // IPv4
            request.append(ipv4.rawValue)
        } else if let ipv6 = IPv6Address(destinationHost) {
            request.append(0x04) // IPv6
            request.append(ipv6.rawValue)
        } else {
            // Domain name
            request.append(0x03) // Domain name
            let hostData = destinationHost.data(using: .utf8)!
            request.append(UInt8(hostData.count))
            request.append(hostData)
        }
        
        // Add destination port
        request.append(UInt8(destinationPort >> 8))
        request.append(UInt8(destinationPort & 0xFF))
        
        connection.send(content: request, completion: .contentProcessed { error in
            if let error = error {
                errlog("SOCKSProxyHandler: Failed to send SOCKS5 connection request: \(error)")
                return
            }
            
            // Read connection response
            connection.receive(minimumIncompleteLength: 4, maximumLength: 256) { data, _, isComplete, error in
                guard let data = data, data.count >= 4, data[0] == 0x05, data[1] == 0x00 else {
                    errlog("SOCKSProxyHandler: SOCKS5 connection request failed")
                    return
                }
                
                infolog("SOCKSProxyHandler: SOCKS5 connection established for \(destinationHost):\(destinationPort)")
                
                // Start forwarding data
                self.startDataForwarding(
                    connection: connection,
                    originalPacket: originalPacket,
                    flow: flow
                )
            }
        })
    }
    
    private func startDataForwarding(
        connection: NWConnection,
        originalPacket: Data,
        flow: NEPacketTunnelFlow
    ) {
        // Extract payload from original packet and send through SOCKS connection
        if let payload = extractPayload(from: originalPacket) {
            connection.send(content: payload, completion: .contentProcessed { error in
                if let error = error {
                    errlog("SOCKSProxyHandler: Failed to send payload through SOCKS: \(error)")
                }
            })
        }
        
        // Start receiving data from SOCKS connection and forward back to tunnel
        receiveFromSOCKS(connection: connection, flow: flow)
    }
    
    private func receiveFromSOCKS(connection: NWConnection, flow: NEPacketTunnelFlow) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                // Create response packet and write to tunnel
                if let responsePacket = self?.createResponsePacket(payload: data) {
                    flow.writePackets([responsePacket], withProtocols: [NSNumber(value: AF_INET)])
                }
            }
            
            if isComplete || error != nil {
                self?.removeConnection(connection)
            } else {
                // Continue receiving
                self?.receiveFromSOCKS(connection: connection, flow: flow)
            }
        }
    }
    
    private func extractPayload(from packet: Data) -> Data? {
        // Extract TCP/UDP payload from IP packet
        guard packet.count >= 20 else { return nil }
        
        let headerLength = Int(packet[0] & 0x0F) * 4
        let protocolByte = packet[9]
        
        if protocolByte == 6 { // TCP
            guard packet.count >= headerLength + 20 else { return nil }
            let tcpHeaderLength = Int((packet[headerLength + 12] & 0xF0) >> 4) * 4
            let payloadStart = headerLength + tcpHeaderLength
            guard packet.count > payloadStart else { return nil }
            return packet.subdata(in: payloadStart..<packet.count)
        } else if protocolByte == 17 { // UDP
            guard packet.count >= headerLength + 8 else { return nil }
            let payloadStart = headerLength + 8
            return packet.subdata(in: payloadStart..<packet.count)
        }
        
        return nil
    }
    
    private func createResponsePacket(payload: Data) -> Data {
        // Create a basic IP packet with the response payload
        // This is a simplified implementation - in practice, you'd need to
        // properly construct IP/TCP/UDP headers based on the original request
        
        var packet = Data()
        
        // IPv4 header (simplified)
        packet.append(0x45) // Version 4, header length 20
        packet.append(0x00) // Type of service
        
        let totalLength = UInt16(20 + payload.count) // IP header + payload
        packet.append(UInt8(totalLength >> 8))
        packet.append(UInt8(totalLength & 0xFF))
        
        packet.append(contentsOf: [0x00, 0x00]) // Identification
        packet.append(contentsOf: [0x40, 0x00]) // Flags and fragment offset
        packet.append(0x40) // TTL
        packet.append(0x06) // Protocol (TCP)
        packet.append(contentsOf: [0x00, 0x00]) // Header checksum (should be calculated)
        
        // Source IP (proxy)
        packet.append(contentsOf: [127, 0, 0, 1])
        // Destination IP (client) - should be extracted from original packet
        packet.append(contentsOf: [192, 168, 1, 100]) // Placeholder
        
        // Append payload
        packet.append(payload)
        
        return packet
    }
    
    private func removeConnection(_ connection: NWConnection) {
        connectionQueue.async {
            if let index = self.activeConnections.firstIndex(where: { $0 === connection }) {
                self.activeConnections.remove(at: index)
            }
            connection.cancel()
        }
    }
    
    private func closeAllConnections() {
        connectionQueue.async {
            for connection in self.activeConnections {
                connection.cancel()
            }
            self.activeConnections.removeAll()
        }
    }
}
