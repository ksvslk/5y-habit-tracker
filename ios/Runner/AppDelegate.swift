import UIKit
import Flutter
import BackgroundAssets

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler, BAAssetPackManagerDelegate {
    
    private let CHANNEL_METHOD = "com.example.fiveyear/asset_delivery"
    private let CHANNEL_EVENT = "com.example.fiveyear/asset_progress"
    
    private var eventSink: FlutterEventSink?
    
    // Hardcoded to match your Dart side "_modelFileName"
    private let MODEL_FILENAME = "model"
    private let MODEL_EXTENSION = "task"
    
    // Asset Pack ID - must match the assetPackID in your Manifest.json
    private let ASSET_PACK_ID = "model_pack"
    
    private var downloadResultCallback: FlutterResult?
    private var progressObservation: NSKeyValueObservation?

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
        
        // 3. Setup Managed Asset Pack Manager
        if #available(iOS 17.0, *) {
            BAAssetPackManager.shared.delegate = self
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

        if #available(iOS 17.0, *) {
            Task {
                do {
                    // Fetch the asset pack state
                    let assetPacks = try await BAAssetPackManager.shared.fetchAssetPacks()
                    
                    guard let assetPack = assetPacks.first(where: { $0.identifier == ASSET_PACK_ID }) else {
                        DispatchQueue.main.async {
                            result(nil)
                        }
                        return
                    }
                    
                    // Check if downloaded
                    if assetPack.state == .downloaded {
                        // Find the model file in the asset pack
                        let fileURL = assetPack.url.appendingPathComponent("\(MODEL_FILENAME).\(MODEL_EXTENSION)")
                        
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            let directory = fileURL.deletingLastPathComponent().path
                            DispatchQueue.main.async {
                                result(directory)
                            }
                        } else {
                            DispatchQueue.main.async {
                                result(nil)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            result(nil)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "FETCH_FAILED",
                                          message: error.localizedDescription,
                                          details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED_VERSION",
                              message: "Managed Asset Packs require iOS 17.0+",
                              details: nil))
        }
    }

    // --- LOGIC: Fetch/Download ---
    private func fetchAsset(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let packName = args["packName"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "Pack name is null", details: nil))
            return
        }

        if #available(iOS 17.0, *) {
            downloadAssetPack(result: result)
        } else {
            result(FlutterError(code: "UNSUPPORTED_VERSION",
                              message: "Managed Asset Packs require iOS 17.0+",
                              details: nil))
        }
    }
    
    @available(iOS 17.0, *)
    private func downloadAssetPack(result: @escaping FlutterResult) {
        Task {
            do {
                // Fetch current asset packs
                let assetPacks = try await BAAssetPackManager.shared.fetchAssetPacks()
                
                guard let assetPack = assetPacks.first(where: { $0.identifier == ASSET_PACK_ID }) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "PACK_NOT_FOUND",
                                          message: "Asset pack '\(self.ASSET_PACK_ID)' not found",
                                          details: nil))
                    }
                    return
                }
                
                // Check if already downloaded
                if assetPack.state == .downloaded {
                    let fileURL = assetPack.url.appendingPathComponent("\(MODEL_FILENAME).\(MODEL_EXTENSION)")
                    let directory = fileURL.deletingLastPathComponent().path
                    DispatchQueue.main.async {
                        result(directory)
                    }
                    return
                }
                
                // Store callback for when download completes
                self.downloadResultCallback = result
                
                // Setup progress monitoring
                self.progressObservation = assetPack.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                    DispatchQueue.main.async {
                        self?.eventSink?(progress.fractionCompleted)
                    }
                }
                
                // Request download
                try await BAAssetPackManager.shared.requestDownload(for: assetPack)
                
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "DOWNLOAD_FAILED",
                                      message: error.localizedDescription,
                                      details: nil))
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
        progressObservation?.invalidate()
        progressObservation = nil
        return nil
    }
    
    // --- BAAssetPackManagerDelegate ---
    @available(iOS 17.0, *)
    func assetPackManager(_ manager: BAAssetPackManager,
                         assetPack: BAAssetPack,
                         didUpdateProgress progress: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(progress)
        }
    }
    
    @available(iOS 17.0, *)
    func assetPackManager(_ manager: BAAssetPackManager,
                         assetPack: BAAssetPack,
                         didCompleteDownloadAt location: URL) {
        
        guard assetPack.identifier == ASSET_PACK_ID else { return }
        
        // Cleanup
        progressObservation?.invalidate()
        progressObservation = nil
        
        // Send 100% progress
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(1.0)
            
            // Return directory path
            if let callback = self?.downloadResultCallback {
                let fileURL = location.appendingPathComponent("\(self?.MODEL_FILENAME ?? "model").\(self?.MODEL_EXTENSION ?? "task")")
                let directory = fileURL.deletingLastPathComponent().path
                callback(directory)
                self?.downloadResultCallback = nil
            }
        }
    }
    
    @available(iOS 17.0, *)
    func assetPackManager(_ manager: BAAssetPackManager,
                         assetPack: BAAssetPack,
                         failedWithError error: Error) {
        
        guard assetPack.identifier == ASSET_PACK_ID else { return }
        
        // Cleanup
        progressObservation?.invalidate()
        progressObservation = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(FlutterError(code: "DOWNLOAD_FAILED",
                                          message: error.localizedDescription,
                                          details: nil))
            
            if let callback = self?.downloadResultCallback {
                callback(FlutterError(code: "DOWNLOAD_FAILED",
                                    message: error.localizedDescription,
                                    details: nil))
                self?.downloadResultCallback = nil
            }
        }
    }
}
