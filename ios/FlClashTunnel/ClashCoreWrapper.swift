import Foundation
import ClashCore

@objc class ClashCoreWrapper: NSObject {

    @objc static func start(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let config = ClashCoreWrapper.getConfig()
            do {
                let core = ClashCore()
                try core.start(config: config)
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    @objc static func stop() {
        do {
            let core = ClashCore()
            try core.stop()
        } catch {
            // ignore
        }
    }

    @objc static func sendMessage(_ message: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let core = ClashCore()
                let response = try core.invoke(method: "message", args: message)
                DispatchQueue.main.async {
                    completion(response)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    @objc static func isRunning() -> Bool {
        let core = ClashCore()
        return core.isRunning()
    }

    static func getConfig() -> String {
        return "{}"
    }
}