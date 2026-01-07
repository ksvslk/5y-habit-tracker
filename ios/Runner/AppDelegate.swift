import UIKit
import Flutter
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    
    private let CHANNEL_METHOD = "com.indest.fiveyearhabittracker/asset_delivery"
    private let CHANNEL_EVENT = "com.indest.fiveyearhabittracker/asset_progress"
    
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

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }
        
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
            request.conditionallyBeginAccessingResources { [weak self] available in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    if available {
                        // CRITICAL FIX: Save the request to the class property.
                        // This tells iOS: "Keep this file on disk, I am using it now."
                        // If we had an old request, this replaces it (releasing the old one).
                        self.resourceRequest = request
                        
                        // Now it is safe to look up the path
                        if let path = Bundle.main.path(forResource: self.MODEL_FILENAME, ofType: self.MODEL_EXTENSION) {
                            let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
                            result(directory)
                        } else {
                            // Tag claims it's there, but file is missing (rare, but possible)
                            self.resourceRequest = nil
                            result(nil)
                        }
                    } else {
                        // Not available, no need to keep the request
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
    
    // Clean up any existing request first
    progressObservation?.invalidate()
    progressObservation = nil
    
    resourceRequest = NSBundleResourceRequest(tags: tags)
    
    guard let request = resourceRequest else {
        result(FlutterError(code: "REQUEST_FAILED", message: "Failed to create resource request", details: nil))
        return
    }

    // Send initial 0% progress immediately
    DispatchQueue.main.async { [weak self] in
        self?.eventSink?(0.0)
    }
    
    // Setup Progress Monitoring BEFORE starting download
    progressObservation = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
        DispatchQueue.main.async {
            guard let self = self, let sink = self.eventSink else { return }
            let progressValue = progress.fractionCompleted
            print("ODR Progress: \(progressValue)")  // Debug logging
            sink(progressValue)
        }
    }

    // Small delay to ensure observer is fully set up
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        guard let self = self else { return }
        
        // Start Accessing (Downloads if needed)
        request.beginAccessingResources { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Cleanup observer
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                
                if let error = error {
                    let flutterError = FlutterError(code: "DOWNLOAD_FAILED", message: error.localizedDescription, details: nil)
                    self.eventSink?(flutterError)
                    result(flutterError)
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
    
    deinit {
        resourceRequest?.endAccessingResources()
        progressObservation?.invalidate()
    }
}