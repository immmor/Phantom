import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var session: NWUDPSession?
    private var pendingStartCompletion: ((Error?) -> Void)?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        pendingStartCompletion = completionHandler

        let tunnelNetworkSettings = createTunnelSettings()

        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                self?.pendingStartCompletion?(error)
                return
            }

            self?.startClash()
            self?.pendingStartCompletion?(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        stopClash()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let message = String(data: messageData, encoding: .utf8) {
            handleMessage(message)
        }
        completionHandler?(nil)
    }

    private func createTunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")

        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings

        let ipv6Settings = NEIPv6Settings(addresses: ["fd00::2"], networkPrefixLengths: [64])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6Settings

        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        settings.dnsSettings = dnsSettings

        settings.mtu = 9000

        return settings
    }

    private func startClash() {
        ClashCoreWrapper.start { [weak self] success, error in
            if !success {
                self?.cancelTunnelWithError(NSError(domain: "FlClashTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: error ?? "Unknown error"]))
            }
        }
    }

    private func stopClash() {
        ClashCoreWrapper.stop()
    }

    private func handleMessage(_ message: String) {
        ClashCoreWrapper.sendMessage(message) { [weak self] response in
            if let responseData = response?.data(using: .utf8) {
                self?.handleAppMessage(responseData, completionHandler: nil)
            }
        }
    }
}