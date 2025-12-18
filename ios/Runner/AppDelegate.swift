import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    
    private let CHANNEL_METHOD = "com.example.fiveyear/asset_delivery"
    private let CHANNEL_EVENT = "com.example.fiveyear/asset_progress"
    
    // ODR Request Object
    private var resourceRequest: NSBundleResourceRequest?
    private var eventSink: FlutterEventSink?
    private var progressObservation: NSKeyValueObservation?
    
    // Hardcoded to match your Dart side "_modelFileName"
    // Dart code does: "$packPath/$_modelFileName" -> "$packPath/model.task"
    private let MODEL_FILENAME = "model"
    private let MODEL_EXTENSION = "task"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // 1. Setup Method Channel
        let methodChannel = FlutterMethodChannel(name: CHANNEL_METHOD,
                                                 binaryMessenger: controller.binaryMessenger)
        
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            if call.method == "getAssetPackPathIfExists" {
                self.checkAssetIfExists(call: call, result: result)
            } else if call.method == "getAssetPackPath" {
                self.fetchAsset(call: call, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        // 2. Setup Event Channel (for progress)
        let eventChannel = FlutterEventChannel(name: CHANNEL_EVENT,
                                               binaryMessenger: controller.binaryMessenger)
        eventChannel.setStreamHandler(self)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // --- LOGIC: Check if Exists ---
    private func checkAssetIfExists(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let packName = args["packName"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "Pack name is null", details: nil))
            return
        }

        let tags: Set<String> = [packName]
        let request = NSBundleResourceRequest(tags: tags)
        
        // Check if locally available without downloading
        request.conditionallyBeginAccessingResources { available in
            DispatchQueue.main.async {
                if available {
                    // Resource is ready. Find the path.
                    if let path = Bundle.main.path(forResource: self.MODEL_FILENAME, ofType: self.MODEL_EXTENSION) {
                        // Dart expects the DIRECTORY, not the file.
                        let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
                        result(directory)
                    } else {
                        // Tag exists, but file not found in bundle (Configuration error?)
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            }
        }
    }

    // --- LOGIC: Fetch/Download ---
    private func fetchAsset(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let packName = args["packName"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "Pack name is null", details: nil))
            return
        }

        let tags: Set<String> = [packName]
        resourceRequest = NSBundleResourceRequest(tags: tags)
        
        // 1. Setup Progress Monitoring
        progressObservation = resourceRequest?.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.eventSink?(progress.fractionCompleted)
            }
        }

        // 2. Start Accessing (Downloads if needed)
        resourceRequest?.beginAccessingResources { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Cleanup observer
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                
                if let error = error {
                    self.eventSink?(FlutterError(code: "DOWNLOAD_FAILED", message: error.localizedDescription, details: nil))
                    result(FlutterError(code: "DOWNLOAD_FAILED", message: error.localizedDescription, details: nil))
                    return
                }

                // Success! Send 100% progress
                self.eventSink?(1.0)
                
                // Find path
                if let path = Bundle.main.path(forResource: self.MODEL_FILENAME, ofType: self.MODEL_EXTENSION) {
                    let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
                    result(directory)
                } else {
                    result(FlutterError(code: "FILE_NOT_FOUND", message: "Download success, but model.task not found in bundle", details: nil))
                }
            }
        }
    }

    // --- StreamHandler Implementation ---
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
