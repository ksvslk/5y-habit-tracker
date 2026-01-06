package com.indest.fiveyearhabittracker // REPLACE WITH YOUR ACTUAL PACKAGE NAME

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.assetpacks.AssetPackManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.android.play.core.assetpacks.AssetPackState
import com.google.android.play.core.assetpacks.AssetPackStateUpdateListener
import com.google.android.play.core.assetpacks.model.AssetPackStatus

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL_METHOD = "com.indest.fiveyearhabittracker/asset_delivery"
    private val CHANNEL_EVENT = "com.indest.fiveyearhabittracker/asset_progress"
    
    private var assetPackManager: AssetPackManager? = null
    private var eventSink: EventChannel.EventSink? = null
    
    // Store the pending result to complete when download finishes
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPackName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize AssetPackManager here instead of as a lateinit property
        assetPackManager = AssetPackManagerFactory.getInstance(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_METHOD).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAssetPackPathIfExists" -> {
                    val assetPackName = call.argument<String>("packName")
                    if (assetPackName != null) {
                        checkAssetPackExists(assetPackName, result)
                    } else {
                        result.error("INVALID_ARG", "Pack name is null", null)
                    }
                }
                "getAssetPackPath" -> {
                    val assetPackName = call.argument<String>("packName")
                    if (assetPackName != null) {
                        fetchAssetPack(assetPackName, result)
                    } else {
                        result.error("INVALID_ARG", "Pack name is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_EVENT).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    assetPackManager?.registerListener(listener)
                }

                override fun onCancel(arguments: Any?) {
                    assetPackManager?.unregisterListener(listener)
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
                    eventSink?.success(1.0)
                }
                
                pendingResult?.let { result ->
                    pendingPackName?.let { packName ->
                        val location = assetPackManager?.getPackLocation(packName)
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
        val manager = assetPackManager
        if (manager == null) {
            result.error("NOT_INITIALIZED", "AssetPackManager not initialized", null)
            return
        }

        // 1. Check if already exists
        val packLocation = manager.getPackLocation(packName)
        if (packLocation != null) {
            result.success(packLocation.assetsPath())
            return
        }

        // 2. Start download and wait for completion
        pendingResult = result
        pendingPackName = packName
        
        val fetchList = listOf(packName)
        manager.fetch(fetchList)
            .addOnFailureListener { exception ->
                runOnUiThread {
                    result.error("DOWNLOAD_FAILED", exception.message, null)
                }
                pendingResult = null
                pendingPackName = null
            }
    }

    private fun checkAssetPackExists(packName: String, result: MethodChannel.Result) {
        val manager = assetPackManager
        if (manager == null) {
            result.error("NOT_INITIALIZED", "AssetPackManager not initialized", null)
            return
        }

        val packLocation = manager.getPackLocation(packName)
        if (packLocation != null) {
            result.success(packLocation.assetsPath())
        } else {
            result.success(null)
        }
    }

    override fun onDestroy() {
        assetPackManager?.unregisterListener(listener)
        super.onDestroy()
    }
}