import 'dart:async';
import 'package:fiveyear/data/chat_repository.dart';
import 'package:fiveyear/data/database_provider.dart';
import 'package:fiveyear/services/gemma_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dbFuture = ref.watch(isarDatabaseProvider.future);
  return ChatRepository(dbFuture);
});

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    return ChatController(
      ref.watch(gemmaServiceProvider),
      ref.watch(chatRepositoryProvider),
    );
  },
);

class ChatMessage {
  final ValueNotifier<String> content;
  final bool isUser;
  ChatMessage({required String text, required this.isUser})
    : content = ValueNotifier(text);
  void append(String token) => content.value += token;
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoadingEngine,
      isDownloading,
      isThinking,
      isCheckingForModel,
      needsDownload,
      isStopping;
  final double downloadProgress;
  final int usedTokens, maxTokens;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoadingEngine = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.isThinking = false,
    this.isCheckingForModel = true,
    this.needsDownload = false,
    this.isStopping = false,
    this.usedTokens = 0,
    this.maxTokens = 2048,
    this.error,
  });

  double get memoryPercentage => usedTokens / maxTokens;
  bool get isMemoryFull => usedTokens >= maxTokens;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoadingEngine,
    bool? isDownloading,
    bool? isThinking,
    bool? isCheckingForModel,
    bool? needsDownload,
    bool? isStopping,
    double? downloadProgress,
    int? usedTokens,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoadingEngine: isLoadingEngine ?? this.isLoadingEngine,
      isDownloading: isDownloading ?? this.isDownloading,
      isThinking: isThinking ?? this.isThinking,
      isCheckingForModel: isCheckingForModel ?? this.isCheckingForModel,
      needsDownload: needsDownload ?? this.needsDownload,
      isStopping: isStopping ?? this.isStopping,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      usedTokens: usedTokens ?? this.usedTokens,
      maxTokens: maxTokens,
      error: error,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  final GemmaService _service;
  final ChatRepository _repo;
  StreamSubscription? _chatSubscription;
  Timer? _timeoutTimer;
  
  // Track the current AI message being generated
  ChatMessage? _currentAiMessage;
  bool _isGenerating = false;

  ChatController(this._service, this._repo) : super(ChatState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final history = await _repo.getHistory();
    final msgs = history
        .map((e) => ChatMessage(text: e.text ?? "", isUser: e.isUser ?? false))
        .toList();
        
    int initialTokens = 0;

    state = state.copyWith(
      messages: msgs,
      usedTokens: initialTokens,
      isCheckingForModel: true,
    );

    try {
      if (await _service.isModelDownloaded()) {
        state = state.copyWith(isCheckingForModel: false);
        await _bootUpAi();
      } else {
        state = state.copyWith(isCheckingForModel: false, needsDownload: true);
      }
    } catch (e) {
      state = state.copyWith(isCheckingForModel: false, error: "Init failed");
    }
  }

  Future<void> downloadAndStart() async {
    if (state.isDownloading) return;
    state = state.copyWith(isDownloading: true, error: null);

    try {
      await _service.init(); 
      await for (final p in _service.downloadModel()) {
        state = state.copyWith(downloadProgress: p);
      }
      state = state.copyWith(
        isDownloading: false, 
        downloadProgress: 1.0, 
        needsDownload: false
      );
      await _bootUpAi();
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        needsDownload: true,
        error: "Download failed.",
      );
    }
  }

  Future<void> _bootUpAi() async {
    if (state.isLoadingEngine) return;
    state = state.copyWith(isLoadingEngine: true, error: null, needsDownload: false);
    try {
      await _service.init(); 
      await _service.loadEngine();
      await _service.performSecureReset();
      state = state.copyWith(isLoadingEngine: false);
    } catch (e) {
      state = state.copyWith(isLoadingEngine: false, error: "AI Engine refused to start.");
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isGenerating || state.isLoadingEngine) return;

    final userMsg = ChatMessage(text: text, isUser: true);
    final aiMsg = ChatMessage(text: "", isUser: false);
    
    _currentAiMessage = aiMsg;
    _isGenerating = true;

    state = state.copyWith(
      messages: [aiMsg, userMsg, ...state.messages],
      isThinking: true,
      usedTokens: state.usedTokens + (text.length / 3.5).ceil(),
      error: null,
    );
    
    _repo.saveMessage(text, true).ignore(); 

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_isGenerating) {
        print("⏱️ Generation timeout!");
        _forceStopGeneration();
      }
    });

    _performGeneration(text, aiMsg);
  }

  void _performGeneration(String text, ChatMessage aiMsg) {
    bool gotAnyTokens = false;
    int tokensGenerated = 0;

    print("🔵 Starting generation. Current tokens: ${state.usedTokens}/${state.maxTokens}");

    try {
      _chatSubscription = _service.streamResponse(text).listen(
        (token) {
          // Ignore tokens if we've been stopped
          if (!_isGenerating) {
            print("⚠️ Received token after stop, ignoring");
            return;
          }
          
          gotAnyTokens = true;
          tokensGenerated++;
          aiMsg.append(token);
          
          if (tokensGenerated % 10 == 0) {
            state = state.copyWith(usedTokens: state.usedTokens + 10);
          }
        },
        onDone: () {
          // Only process if we're still generating (not stopped)
          if (!_isGenerating) {
            print("⚠️ onDone called after stop, ignoring");
            return;
          }
          
          print("✅ Generation done. Got tokens: $gotAnyTokens, Total generated: $tokensGenerated");
          _timeoutTimer?.cancel();
          
          if (tokensGenerated % 10 != 0) {
            state = state.copyWith(usedTokens: state.usedTokens + (tokensGenerated % 10));
          }
          
          _isGenerating = false;
          _currentAiMessage = null;
          state = state.copyWith(isThinking: false, isStopping: false);
          
          if (gotAnyTokens && aiMsg.content.value.trim().isNotEmpty) {
            _repo.saveMessage(aiMsg.content.value, false);
          } else if (!gotAnyTokens) {
             print("❌ NO TOKENS RECEIVED - Memory full?");
             _handleGenerationFailure(aiMsg);
             state = state.copyWith(error: "Memory Full. Please clear chat.");
          }
        },
        onError: (e) {
          if (!_isGenerating) {
            print("⚠️ onError called after stop, ignoring");
            return;
          }
          
          print("❌ Generation error: $e");
          _timeoutTimer?.cancel();
          _isGenerating = false;
          _currentAiMessage = null;
          _handleGenerationFailure(aiMsg);
          state = state.copyWith(
            isThinking: false, 
            isStopping: false,
            error: "Brain needs a rest. Please clear chat."
          );
        },
      );
    } catch (e) {
      print("❌ Stream setup error: $e");
      _isGenerating = false;
      _currentAiMessage = null;
      _handleGenerationFailure(aiMsg);
      state = state.copyWith(
        isThinking: false,
        isStopping: false,
        error: "Connection error."
      );
    }
  }

  void _handleGenerationFailure(ChatMessage aiMsg) {
    final currentMsgs = List<ChatMessage>.from(state.messages);
    // Remove if empty OR only whitespace
    if (aiMsg.content.value.trim().isEmpty && currentMsgs.contains(aiMsg)) {
      currentMsgs.remove(aiMsg);
      state = state.copyWith(messages: currentMsgs);
    }
  }

  /// Force stop with guaranteed state cleanup
  void _forceStopGeneration() {
    print("🛑 Force stopping generation...");
    
    // Mark as stopped FIRST
    _isGenerating = false;
    
    // Cancel timers and streams
    _timeoutTimer?.cancel();
    _chatSubscription?.cancel();
    
    // Remove empty AI message if exists
    if (_currentAiMessage != null) {
      _handleGenerationFailure(_currentAiMessage!);
    }
    
    _currentAiMessage = null;
    
    // Force state update
    state = state.copyWith(
      isThinking: false,
      isStopping: false,
    );
    
    // Try to stop service (but don't wait for it)
    _service.stopGeneration().catchError((e) {
      print("⚠️ Service stop error (ignored): $e");
    });
    
    print("✅ Force stop complete");
  }

  Future<void> stopGeneration() async {
    if (!_isGenerating) {
      print("⚠️ Not generating, nothing to stop");
      state = state.copyWith(isThinking: false, isStopping: false);
      return;
    }
    
    print("🛑 User requested stop...");
    state = state.copyWith(isStopping: true);
    
    // Create a timeout for the stop operation itself
    bool stopCompleted = false;
    
    // Start the stop operation
    final stopFuture = Future.microtask(() async {
      _forceStopGeneration();
      stopCompleted = true;
    });
    
    // Wait max 2 seconds for stop to complete
    await stopFuture.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        print("⚠️ Stop operation timed out, forcing cleanup");
        if (!stopCompleted) {
          _forceStopGeneration();
        }
      },
    );
    
    print("✅ Stop completed");
  }

  Future<void> clearMemory() async {
    print("🗑️ Clearing memory...");
    
    // Force stop any generation first
    if (_isGenerating) {
      _forceStopGeneration();
    }
    
    state = state.copyWith(isLoadingEngine: true);
    
    // Clear database FIRST
    await _repo.clearHistory();
    print("   ✅ Database cleared");
    
    try {
      // Use clearHistory() API to wipe the AI's conversation context
      await _service.performSecureReset();
      print("   ✅ AI context cleared");
      
      _currentAiMessage = null;
      _isGenerating = false;
      
      state = ChatState(
        messages: [],
        usedTokens: 0,
        maxTokens: 2048,
        isLoadingEngine: false,
        isThinking: false,
        isStopping: false,
        isDownloading: false,
        isCheckingForModel: false,
        needsDownload: false,
        downloadProgress: 0.0,
        error: null,
      );
      
      print("✅ Memory cleared completely");
    } catch (e) {
      print("❌ Reset failed: $e");
      state = state.copyWith(
        isLoadingEngine: false,
        error: "Reset failed: $e",
      );
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _chatSubscription?.cancel();
    _isGenerating = false;
    _currentAiMessage = null;
    super.dispose();
  }
}

extension FutureIgnore on Future {
  void ignore() {}
}