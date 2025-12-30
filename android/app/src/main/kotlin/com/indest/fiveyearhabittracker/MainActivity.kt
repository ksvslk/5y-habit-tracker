package com.indest.fiveyearhabittracker // REPLACE WITH YOUR ACTUAL PACKAGE NAME

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.assetpacks.AssetPackManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.android.play.core.assetpacks.AssetPackState
import com.google.android.play.core.assetpacks.AssetPackStateUpdateListener
import com.google.android.play.core.assetpacks.model.AssetPackStatus

class MainActivity: FlutterActivity() {
    private val CHANNEL_METHOD = "com.example.fiveyear/asset_delivery"
    private val CHANNEL_EVENT = "com.example.fiveyear/asset_progress"
    
    private lateinit var assetPackManager: AssetPackManager
    private var eventSink: EventChannel.EventSink? = null
    
    // Store the pending result to complete when download finishes
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPackName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        assetPackManager = AssetPackManagerFactory.getInstance(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_METHOD).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAssetPackPathIfExists" -> {
                    val assetPackName = call.argument<String>("packName")
                    if (assetPackName != null) {
                        checkAssetPackExists(assetPackName, result)  // New method - just checks
                    } else {
                        result.error("INVALID_ARG", "Pack name is null", null)
                    }
                }
                "getAssetPackPath" -> {
                    val assetPackName = call.argument<String>("packName")
                    if (assetPackName != null) {
                        fetchAssetPack(assetPackName, result)  // Existing method - downloads
                    } else {
                        result.error("INVALID_ARG", "Pack name is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Event Channel remains the same
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_EVENT).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    assetPackManager.registerListener(listener)
                }

                override fun onCancel(arguments: Any?) {
                    assetPackManager.unregisterListener(listener)
                    eventSink = null
                }
            }
        )
    }

    // The Listener that watches for updates
    private val listener = AssetPackStateUpdateListener { state ->
        when (state.status()) {
            AssetPackStatus.DOWNLOADING -> {
                val total = state.totalBytesToDownload()
                val downloaded = state.bytesDownloaded()
                if (total > 0) {
                    val progress = downloaded.toDouble() / total.toDouble()
                    if (progress.isFinite()) {
                        runOnUiThread {
                            eventSink?.success(progress)
                        }
                    }
                }
            }
            AssetPackStatus.COMPLETED -> {
                runOnUiThread {
                    eventSink?.success(1.0) // Ensure we hit 100%
                }
                
                // If we have a pending result, complete it now
                pendingResult?.let { result ->
                    pendingPackName?.let { packName ->
                        val location = assetPackManager.getPackLocation(packName)
                        runOnUiThread {
                            result.success(location?.assetsPath())
                        }
                        pendingResult = null
                        pendingPackName = null
                    }
                }
            }
            AssetPackStatus.FAILED -> {
                runOnUiThread {
                    eventSink?.error("DOWNLOAD_FAILED", "Asset pack download failed", null)
                }
                
                pendingResult?.let { result ->
                    runOnUiThread {
                        result.error("DOWNLOAD_FAILED", "Asset pack download failed", null)
                    }
                    pendingResult = null
                    pendingPackName = null
                }
            }
            AssetPackStatus.CANCELED -> {
                runOnUiThread {
                    eventSink?.error("DOWNLOAD_CANCELED", "Asset pack download canceled", null)
                }
                
                pendingResult?.let { result ->
                    runOnUiThread {
                        result.error("DOWNLOAD_CANCELED", "Asset pack download canceled", null)
                    }
                    pendingResult = null
                    pendingPackName = null
                }
            }
        }
    }

    private fun fetchAssetPack(packName: String, result: MethodChannel.Result) {
        // 1. Check if already exists
        val packLocation = assetPackManager.getPackLocation(packName)
        if (packLocation != null) {
            result.success(packLocation.assetsPath())
            return
        }

        // 2. Start download and wait for completion
        pendingResult = result
        pendingPackName = packName
        
        val fetchList = listOf(packName)
        assetPackManager.fetch(fetchList)
            .addOnFailureListener { exception ->
                runOnUiThread {
                    result.error("DOWNLOAD_FAILED", exception.message, null)
                }
                pendingResult = null
                pendingPackName = null
            }
        // Note: We don't call result.success() here anymore
        // It will be called when the listener receives COMPLETED status
    }

    // NEW METHOD: Just checks if pack exists, doesn't download
    private fun checkAssetPackExists(packName: String, result: MethodChannel.Result) {
        val packLocation = assetPackManager.getPackLocation(packName)
        if (packLocation != null) {
            result.success(packLocation.assetsPath())
        } else {
            result.success(null)  // Return null if doesn't exist, don't download
        }
    }
}