import Foundation
import Flutter

class ServicePlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ServicePlugin()
        instance.setupChannels()
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
    }

    private func setupChannels() {
        methodChannel = FlutterMethodChannel(
            name: "com.follow.clash/service",
            binaryMessenger: FlutterPluginRegistrar.messenger
        )

        eventChannel = FlutterEventChannel(
            name: "com.follow.clash/service_event",
            binaryMessenger: FlutterPluginRegistrar.messenger
        )

        eventChannel?.setStreamHandler(self)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            handleStart(result: result)
        case "stop":
            handleStop(result: result)
        case "init":
            handleInit(result: result)
        case "syncState":
            handleSyncState(call: call, result: result)
        case "shutdown":
            handleShutdown(result: result)
        case "getRunTime":
            handleGetRunTime(result: result)
        case "invokeAction":
            handleInvokeAction(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleStart(result: @escaping FlutterResult) {
        VpnManager.shared.start { success, error in
            if success {
                result(true)
            } else {
                result(FlutterError(code: "VPN_ERROR", message: error, details: nil))
            }
        }
    }

    private func handleStop(result: @escaping FlutterResult) {
        VpnManager.shared.stop()
        result(true)
    }

    private func handleInit(result: @escaping FlutterResult) {
        result("")
    }

    private func handleSyncState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let stateJson = args["state"] as? String else {
            result("")
            return
        }
        result("")
    }

    private func handleShutdown(result: @escaping FlutterResult) {
        VpnManager.shared.stop()
        result(true)
    }

    private func handleGetRunTime(result: @escaping FlutterResult) {
        result(0)
    }

    private func handleInvokeAction(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? String else {
            result("")
            return
        }
        ClashCore.invoke(args) { response in
            DispatchQueue.main.async {
                result(response)
            }
        }
    }

    func sendEvent(_ event: [String: Any]) {
        eventSink?(event)
    }

    func sendCrash(_ message: String) {
        // Handle crash reporting
    }
}

extension ServicePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}