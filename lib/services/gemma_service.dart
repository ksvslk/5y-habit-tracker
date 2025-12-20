import 'dart:async';
import 'dart:io';
import 'package:fiveyear/data/chat_repository.dart';
import 'package:fiveyear/data/database_provider.dart';
import 'package:fiveyear/services/asset_delivery_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- SERVICE PROVIDER ---
final gemmaServiceProvider = Provider<GemmaService>((ref) {
  return GemmaService();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dbFuture = ref.watch(isarDatabaseProvider.future);
  return ChatRepository(dbFuture);
});


class GemmaService {
  final _assetService = AssetDeliveryService();
  
  static const String _assetPackName = "gemma3_1b_it";
  static const String _modelFileName = "model.task";
  
  // The heavy model loaded in GPU memory (Load ONCE)
  InferenceModel? _inferenceModel;
  
  // The current conversation context (Re-create on RESET)
  InferenceChat? _activeChatSession;

  StreamSubscription<double>? _downloadSubscription;

  /// 1. INITIALIZATION CHECK
  /// Returns true if model file exists on disk, false if download needed.
  Future<bool> isModelDownloaded() async {
    final packPath = await _assetService.getAssetPackPathIfExists(_assetPackName);
    if (packPath == null) return false;
    return File("$packPath/$_modelFileName").exists();
  }

  /// 2. DOWNLOADER
  Stream<double> downloadModel() async* {
    final controller = StreamController<double>();
    
    _downloadSubscription = _assetService.downloadProgressStream.listen((p) {
      controller.add(p);
    });

    try {
      final path = await _assetService.fetchAssetPack(_assetPackName);
      if (path == null) throw Exception("Download failed");
      yield 1.0; 
    } finally {
      _downloadSubscription?.cancel();
      await controller.close();
    }
  }

  /// 3. LOAD ENGINE (Heavy Operation)
  Future<void> loadEngine() async {
    if (_inferenceModel != null) return; // Already loaded

    final packPath = await _assetService.getAssetPackPathIfExists(_assetPackName);
    final fullPath = "$packPath/$_modelFileName";

    // Initialize the C++ engine
    await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
        .fromFile(fullPath)
        .install();

    _inferenceModel = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  /// 4. START NEW SESSION (Light Operation - Reset Logic)
  Future<void> startNewSession() async {
    if (_inferenceModel == null) await loadEngine();
    
    // Dispose previous context if exists
    _activeChatSession = null;
    
    // Create new context
    _activeChatSession = await _inferenceModel!.createChat(temperature: 0.7);
    
    // Seed with system prompt
    await _activeChatSession!.addQueryChunk(
      Message.text(text: "You are a habit tracker companion. Try to keep answer under 200 chars.", isUser: false)
    );
  }

  /// 5. STREAM MESSAGE
  Stream<String> streamResponse(String input) async* {
    if (_activeChatSession == null) throw Exception("Session not started");
    
    // Add user message to context
    await _activeChatSession!.addQueryChunk(Message.text(text: input, isUser: true));
    
    // Stream response
    final stream = _activeChatSession!.generateChatResponseAsync();
    
    await for (final chunk in stream) {
      if (chunk is TextResponse && chunk.token.isNotEmpty) {
        yield chunk.token;
      }
    }
  }
}