import Foundation

class ClashCore {
    static let shared = ClashCore()

    private var isInitialized = false

    private init() {}

    func initialize(homeDir: String, version: Int, completion: @escaping (Bool) -> Void) {
        if isInitialized {
            completion(true)
            return
        }
        isInitialized = true
        completion(true)
    }

    func invoke(_ action: String, completion: @escaping (String?) -> Void) {
        guard let data = action.data(using: .utf8) else {
            completion(nil)
            return
        }

        VpnManager.shared.sendMessage(data) { response in
            if let responseData = response,
               let responseString = String(data: responseData, encoding: .utf8) {
                completion(responseString)
            } else {
                completion(nil)
            }
        }
    }

    func shutdown() {
        isInitialized = false
    }
}