import 'dart:async';
import 'dart:io';
import 'package:fiveyear/data/chat_entity_schema.dart';
import 'package:fiveyear/data/chat_repository.dart';
import 'package:fiveyear/data/database_provider.dart';
import 'package:fiveyear/services/asset_delivery_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. REPOSITORY PROVIDER
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dbFuture = ref.watch(isarDatabaseProvider.future);
  return ChatRepository(dbFuture);
});

// 2. STATE
class GemmaState {
  final bool isReady;
  final bool isLoading;
  final bool isDownloading;
  final double downloadProgress;
  final String? error;
  final bool isThinking;
  final bool isCheckingForModel; // Add this

  GemmaState({
    this.isReady = false,
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.error,
    this.isThinking = false,
    this.isCheckingForModel = false,
  });

  GemmaState copyWith({
    bool? isReady,
    bool? isLoading,
    bool? isDownloading,
    double? downloadProgress,
    String? error,
    bool? isThinking,
    bool? isCheckingForModel,
  }) {
    return GemmaState(
      isReady: isReady ?? this.isReady,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error,
      isThinking: isThinking ?? this.isThinking,
      isCheckingForModel: isCheckingForModel ?? this.isCheckingForModel,
    );
  }
}

// 3. NOTIFIER PROVIDER
final gemmaProvider = StateNotifierProvider<GemmaNotifier, GemmaState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return GemmaNotifier(repository);
});

// 4. LOGIC CLASS
class GemmaNotifier extends StateNotifier<GemmaState> {
  final ChatRepository _repository;
  final _assetService = AssetDeliveryService();
  StreamSubscription<double>? _progressSubscription;

  GemmaNotifier(this._repository) : super(GemmaState());

  static const String _assetPackName = "gemma3_1b_it";
  static const String _modelFileName = "model.task";
  static const String _systemPrompt =
      "You are a conversational emotional support and habit forming expert. Keep answers short.";

  InferenceModel? _inferenceModel;
  InferenceChat? _chatSession;

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> init() async {
    if (state.isReady ||
        state.isLoading ||
        state.isDownloading ||
        state.isCheckingForModel)
      return;

    state = state.copyWith(isCheckingForModel: true); // Set flag immediately

    try {
      // Check if model already exists locally WITHOUT triggering download
      final packPath = await _assetService.getAssetPackPathIfExists(
        _assetPackName,
      );

      if (packPath != null) {
        final fullPath = "$packPath/$_modelFileName";
        final modelFile = File(fullPath);

        if (await modelFile.exists()) {
          print("Model file found at $fullPath, loading into memory...");

          // Don't clear isCheckingForModel yet - it will be cleared when loading starts
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
          ).fromFile(fullPath).install();

          await _loadModelIntoMemory();
        } else {
          print("Model file not found, user needs to download");
          state = state.copyWith(isCheckingForModel: false); // Clear flag
        }
      } else {
        print("Asset pack not present, user needs to download");
        state = state.copyWith(isCheckingForModel: false); // Clear flag
      }
    } catch (e) {
      print("Init error: $e");
      state = state.copyWith(
        error: "Init failed: $e",
        isCheckingForModel: false,
      );
    }
  }

  Future<List<ChatEntity>> loadHistory() async {
    return await _repository.getHistory();
  }

  Stream<String> sendMessage(String text) async* {
    if (_chatSession == null) {
      yield "Error: AI not ready";
      return;
    }

    state = state.copyWith(isThinking: true);

    // DON'T persist here - let chat_screen handle it
    // await _repository.saveMessage(text, true);

    final StringBuffer aiBuffer = StringBuffer();

    try {
      await _chatSession!.addQueryChunk(Message.text(text: text, isUser: true));
      final stream = _chatSession!.generateChatResponseAsync();

      await for (final response in stream) {
        if (response is TextResponse) {
          final cleanToken = response.token.replaceAll(r'\n', '');
          aiBuffer.write(cleanToken);
          yield response.token;
        }
      }

      // DON'T persist here either - chat_screen handles it
      // await _repository.saveMessage(aiBuffer.toString(), false);
    } catch (e) {
      yield "[Error: $e]";
    } finally {
      state = state.copyWith(isThinking: false);
    }
  }

  Future<void> downloadAndLoadModel() async {
    if (state.isDownloading || state.isLoading) return;

    try {
      print("Starting download...");
      // Start downloading state
      state = state.copyWith(isDownloading: true, downloadProgress: 0.0);

      // Listen to progress updates from the event channel
      _progressSubscription = _assetService.downloadProgressStream.listen(
        (progress) {
          print("Download progress: ${(progress * 100).toInt()}%");
          state = state.copyWith(
            isDownloading: true,
            downloadProgress: progress,
          );
        },
        onError: (e) {
          print("Progress stream error: $e");
        },
      );

      // Request the asset pack - this now WAITS for download to complete
      print("Requesting asset pack: $_assetPackName");
      final packPath = await _assetService.fetchAssetPack(_assetPackName);

      // Cancel the progress subscription
      await _progressSubscription?.cancel();
      _progressSubscription = null;

      if (packPath == null) {
        print("Asset pack download failed - packPath is null");
        state = state.copyWith(
          isDownloading: false,
          error: "Failed to download asset pack",
        );
        return;
      }

      print("Asset pack downloaded to: $packPath");

      // Install the model
      final fullPath = "$packPath/$_modelFileName";
      final modelFile = File(fullPath);

      print("Checking for model file at: $fullPath");
      if (!await modelFile.exists()) {
        print("Model file not found!");
        state = state.copyWith(
          isDownloading: false,
          error: "Model file not found at $fullPath",
        );
        return;
      }

      print("Model file found, size: ${await modelFile.length()} bytes");
      print("Installing model...");

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(fullPath).install();

      print("Model installed, loading into memory...");

      // Load into memory
      await _loadModelIntoMemory();

      print("Model ready!");
    } catch (e) {
      print("Download/load error: $e");
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      state = state.copyWith(
        isDownloading: false,
        isLoading: false,
        error: "Download failed: $e",
      );
    }
  }

  Future<void> _loadModelIntoMemory() async {
    state = state.copyWith(
      isLoading: true,
      isDownloading: false,
      downloadProgress: 1.0,
       isCheckingForModel: false,
    );

    try {
      _inferenceModel = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
      );

      _chatSession = await _inferenceModel!.createChat(temperature: 0.7);

      await _chatSession!.addQueryChunk(
        Message.text(text: _systemPrompt, isUser: false),
      );

      state = state.copyWith(isReady: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to load model: $e",
      );
    }
  }
}
