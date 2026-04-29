import Foundation
import NetworkExtension

class VpnManager {
    static let shared = VpnManager()

    private var vpnManager: NETunnelProviderManager?
    private var session: NETunnelProviderSession?

    private init() {
        loadVpnConfiguration()
    }

    private func loadVpnConfiguration() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                print("Failed to load VPN configuration: \(error)")
                return
            }

            if let existingManager = managers?.first {
                self?.vpnManager = existingManager
                self?.session = existingManager.connection as? NETunnelProviderSession
            } else {
                self?.createVpnConfiguration()
            }
        }
    }

    private func createVpnConfiguration() {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "FlClash"

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.follow.clash.tunnel"
        proto.serverAddress = "FlClash"
        manager.protocolConfiguration = proto

        manager.isEnabled = true

        manager.saveToPreferences { [weak self] error in
            if let error = error {
                print("Failed to save VPN configuration: \(error)")
                return
            }

            manager.loadFromPreferences { [weak self] error in
                if let error = error {
                    print("Failed to reload VPN configuration: \(error)")
                    return
                }
                self?.vpnManager = manager
                self?.session = manager.connection as? NETunnelProviderSession
            }
        }
    }

    func start(completion: @escaping (Bool, String?) -> Void) {
        guard let session = session else {
            loadVpnConfiguration()
            completion(false, "VPN not configured")
            return
        }

        do {
            try session.startTunnel()
            completion(true, nil)
        } catch let error as NEVPNError {
            completion(false, error.localizedDescription)
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    func stop() {
        session?.stopTunnel()
    }

    func sendMessage(_ data: Data, completion: @escaping (Data?) -> Void) {
        do {
            try session?.sendProviderMessage(data) { response in
                completion(response)
            }
        } catch {
            completion(nil)
        }
    }
}