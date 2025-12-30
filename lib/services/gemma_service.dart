import 'dart:async';
import 'dart:io';
import 'package:fiveyear/services/asset_delivery_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gemmaServiceProvider = Provider<GemmaService>((ref) => GemmaService());

class GemmaService {
  final _assetService = AssetDeliveryService();
  static const String _assetPackName = "gemma3_1b_it"; 
  static const String _modelFileName = "model.task";
  
  InferenceModel? _inferenceModel;
  InferenceChat? _activeChatSession;
  
  bool _isResetting = false;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await FlutterGemma.initialize();
      _isInitialized = true;
    } catch (e) {
      print("⚠️ Init warning: $e");
    }
  }

  Future<bool> isModelDownloaded() async {
    final packPath = await _assetService.getAssetPackPathIfExists(_assetPackName);
    if (packPath == null) return false;
    return File("$packPath/$_modelFileName").exists();
  }

  Stream<double> downloadModel() {
    final controller = StreamController<double>();
    Future.microtask(() async {
      try {
        final downloadFuture = _assetService.fetchAssetPack(_assetPackName);
        final subscription = _assetService.downloadProgressStream.listen((p) {
          if (!controller.isClosed) controller.add(p);
        });
        await downloadFuture;
        await subscription.cancel();
        if (!controller.isClosed) {
          controller.add(1.0);
          await controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    });
    return controller.stream;
  }

  Future<void> loadEngine() async {
    final packPath = await _assetService.getAssetPackPathIfExists(_assetPackName);
    if (packPath == null) throw Exception("Model missing");
    final fullPath = "$packPath/$_modelFileName";
    
    try {
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt).fromFile(fullPath).install();
      _inferenceModel = await FlutterGemma.getActiveModel(
        maxTokens: 2048, 
        preferredBackend: PreferredBackend.gpu
      );
      print("✅ Engine loaded");
    } catch (e) {
      print("❌ Engine load error: $e");
      rethrow;
    }
  }

  /// PROPER RESET: Stop generation, clear history, ready for fresh conversation
  Future<void> performSecureReset() async {
    if (_isResetting) {
      print("⚠️ Already resetting, skipping...");
      return;
    }
    
    _isResetting = true;
    print("🧹 Resetting chat session and clearing history...");
    
    try {
      // STEP 1: Stop any ongoing generation
      if (_activeChatSession != null) {
        try {
          print("   1️⃣ Stopping ongoing generation...");
          await _activeChatSession!.stopGeneration();
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          print("   ⚠️ Stop generation warning: $e");
        }
      }
      
      // STEP 2: Clear the chat history using the proper API
      if (_activeChatSession != null) {
        try {
          print("   2️⃣ Clearing chat history...");
          // THIS IS THE KEY: clearHistory() wipes the conversation context
          await _activeChatSession!.clearHistory();
          print("   ✅ Chat history cleared");
        } catch (e) {
          print("   ⚠️ Clear history warning: $e");
          // If clearHistory fails, create a new chat as fallback
          _activeChatSession = null;
        }
      }
      
      // STEP 3: If no chat exists or clearing failed, create a fresh one
      if (_activeChatSession == null) {
        if (_inferenceModel == null) {
          print("   3️⃣ Loading engine...");
          await loadEngine();
        }
        
        print("   3️⃣ Creating fresh chat session...");
        _activeChatSession = await _inferenceModel!.createChat(
          temperature: 0.7,
          tokenBuffer: 1024,
        );
      }
      
      print("✅ Chat reset complete - fresh context");
    } catch (e) {
      print("❌ Reset failed: $e");
      _activeChatSession = null;
      throw Exception("Failed to reset. Please restart app.");
    } finally {
      _isResetting = false;
    }
  }

  Stream<String> streamResponse(String input) async* {
    if (_isResetting) {
      throw Exception("Brain is rebooting. Please wait.");
    }

    if (_activeChatSession == null) {
      await performSecureReset();
    }
    
    bool hasYielded = false;
    
    try {
      await _activeChatSession!.addQueryChunk(
        Message.text(text: "You are a support companion. Please answer in 2-3 sentences max.\n\n$input", isUser: true)
      );
      
      final stream = _activeChatSession!.generateChatResponseAsync();
      
      await for (final chunk in stream) {
        if (chunk is TextResponse && chunk.token.isNotEmpty) {
          hasYielded = true;
          yield chunk.token;
        }
      }

      if (!hasYielded) {
         print("⚠️ Engine returned 0 tokens. Context likely full.");
         throw Exception("Context Full");
      }

    } catch (e) {
      print("❌ Stream Error: $e");
      rethrow;
    }
  }

  Future<void> stopGeneration() async {
    if (_activeChatSession != null) {
      try {
        await _activeChatSession!.stopGeneration();
      } catch (e) {
        print("⚠️ Stop generation error: $e");
      }
    }
  }
}