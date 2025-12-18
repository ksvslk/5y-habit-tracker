import 'package:flutter/services.dart';
import 'dart:io';

class AssetDeliveryService {
  static const methodChannel = MethodChannel('com.example.fiveyear/asset_delivery');
  static const eventChannel = EventChannel('com.example.fiveyear/asset_progress');

  /// Check if asset pack exists locally (doesn't trigger download)
  Future<String?> getAssetPackPathIfExists(String packName) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final String? path = await methodChannel.invokeMethod(
          'getAssetPackPathIfExists',  // New method name
          {'packName': packName}
        );
        return path;
      }
      return null;
    } on PlatformException catch (e) {
      print("Asset Delivery Error: '${e.message}'.");
      return null;
    }
  }

  /// Requests the asset pack and returns the folder path (triggers download if needed)
  Future<String?> fetchAssetPack(String packName) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final String? path = await methodChannel.invokeMethod(
          'getAssetPackPath', 
          {'packName': packName}
        );
        return path;
      }
      return null;
    } on PlatformException catch (e) {
      print("Asset Delivery Error: '${e.message}'.");
      return null;
    }
  }

  Stream<double> get downloadProgressStream {
    if (Platform.isAndroid) {
      return eventChannel.receiveBroadcastStream().map((event) => (event as num).toDouble());
    }
    return Stream.value(0.0);
  }
}