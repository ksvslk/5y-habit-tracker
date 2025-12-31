import 'dart:async';
import 'package:fiveyear/data/app_settings_repository.dart'; 
import 'package:fiveyear/data/app_settings_provider.dart'; 
import 'package:fiveyear/data/chat_repository.dart';
import 'package:fiveyear/data/database_provider.dart';
import 'package:fiveyear/data/subscription_service.dart'; 
import 'package:fiveyear/services/gemma_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart'; // REQUIRED for Message class
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
      ref.watch(appSettingsRepositoryProvider),
      ref.watch(subscriptionServiceProvider),
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
  
  final bool isDailyLimitReached;

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
    this.isDailyLimitReached = false,
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
    bool? isDailyLimitReached,
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
      isDailyLimitReached: isDailyLimitReached ?? this.isDailyLimitReached,
      maxTokens: maxTokens,
      error: error,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  final GemmaService _service;
  final ChatRepository _repo;
  final AppSettingsRepository _settingsRepo; 
  final SubscriptionService _subscriptionService; 
  
  StreamSubscription? _chatSubscription;
  StreamSubscription? _proStatusSubscription; // Added for real-time updates
  Timer? _timeoutTimer;
  
  ChatMessage? _currentAiMessage;
  bool _isGenerating = false;
  
  // Limit constants
  static const int _dailyFreeTokenLimit = 1024; 

  ChatController(
    this._service, 
    this._repo, 
    this._settingsRepo, 
    this._subscriptionService
  ) : super(ChatState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final history = await _repo.getHistory();
    final msgs = history
        .map((e) => ChatMessage(text: e.text ?? "", isUser: e.isUser ?? false))
        .toList();

    // Listen to real-time subscription changes
    _proStatusSubscription = _subscriptionService.subscriptionStatusStream.listen((isPro) {
      if (isPro && state.isDailyLimitReached) {
        state = state.copyWith(isDailyLimitReached: false);
      }
    });
        
    // Initial check
    await _checkDailyLimit();

    state = state.copyWith(
      messages: msgs,
      usedTokens: 0, 
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

  Future<bool> _checkDailyLimit() async {
    final isPro = await _subscriptionService.hasProEntitlement();
    if (isPro) {
      if (state.isDailyLimitReached) {
         state = state.copyWith(isDailyLimitReached: false);
      }
      return false; 
    }

    final settings = await _settingsRepo.getSettings();
    final used = settings.dailyTokenUsage;
    
    final isReached = used >= _dailyFreeTokenLimit;
    if (state.isDailyLimitReached != isReached) {
      state = state.copyWith(isDailyLimitReached: isReached);
    }
    return isReached;
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
      
      // --- CONTEXT RESTORATION LOGIC ---
      
      // 1. Get messages from state (Newest First) -> Reverse to Oldest First
      // 2. Take last 20 to preserve memory
      final recentHistory = state.messages.reversed
          .take(20)
          .map((m) => Message.text(text: m.content.value, isUser: m.isUser))
          .toList();

      // 3. Define the System Prompt
      final systemPrompt = Message.text(
        text: "You are a support companion. Please answer in 2-3 sentences max.", 
        isUser: false
      );

      // 4. Combine: System Prompt + History
      final fullHistory = [systemPrompt, ...recentHistory];
      
      // 5. Inject into Gemma
      await _service.performSecureReset(history: fullHistory);
      
      // --- END CONTEXT RESTORATION ---

      state = state.copyWith(isLoadingEngine: false);
    } catch (e) {
      state = state.copyWith(isLoadingEngine: false, error: "AI Engine refused to start.");
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty || _isGenerating || state.isLoadingEngine) return false;

    final isLimitReached = await _checkDailyLimit();
    if (isLimitReached) {
      return false; 
    }

    final userMsg = ChatMessage(text: text, isUser: true);
    final aiMsg = ChatMessage(text: "", isUser: false);
    
    _currentAiMessage = aiMsg;
    _isGenerating = true;

    final inputTokens = (text.length / 3.5).ceil();

    state = state.copyWith(
      messages: [aiMsg, userMsg, ...state.messages],
      isThinking: true,
      usedTokens: state.usedTokens + inputTokens,
      error: null,
    );
    
    _repo.saveMessage(text, true).ignore(); 
    
    await _settingsRepo.incrementTokenUsage(inputTokens);

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_isGenerating) {
        print("⏱️ Generation timeout!");
        _forceStopGeneration();
      }
    });

    _performGeneration(text, aiMsg);
    return true;
  }

  void _performGeneration(String text, ChatMessage aiMsg) {
    bool gotAnyTokens = false;
    int tokensGenerated = 0;

    print("🔵 Starting generation...");

    try {
      _chatSubscription = _service.streamResponse(text).listen(
        (token) {
          if (!_isGenerating) return;
          
          gotAnyTokens = true;
          tokensGenerated++;
          aiMsg.append(token);
          
          if (tokensGenerated % 10 == 0) {
            state = state.copyWith(usedTokens: state.usedTokens + 10);
          }
        },
        onDone: () async {
          if (!_isGenerating) return;
          
          print("✅ Generation done. Tokens: $tokensGenerated");
          _timeoutTimer?.cancel();
          
          if (tokensGenerated % 10 != 0) {
            state = state.copyWith(usedTokens: state.usedTokens + (tokensGenerated % 10));
          }
          
          _isGenerating = false;
          _currentAiMessage = null;
          state = state.copyWith(isThinking: false, isStopping: false);
          
          if (gotAnyTokens && aiMsg.content.value.trim().isNotEmpty) {
            _repo.saveMessage(aiMsg.content.value, false);
            
            await _settingsRepo.incrementTokenUsage(tokensGenerated);
            await _checkDailyLimit(); 
          } else if (!gotAnyTokens) {
             _handleGenerationFailure(aiMsg);
             state = state.copyWith(error: "Memory Full. Please clear chat.");
          }
        },
        onError: (e) {
          if (!_isGenerating) return;
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
    if (aiMsg.content.value.trim().isEmpty && currentMsgs.contains(aiMsg)) {
      currentMsgs.remove(aiMsg);
      state = state.copyWith(messages: currentMsgs);
    }
  }

  void _forceStopGeneration() {
    _isGenerating = false;
    _timeoutTimer?.cancel();
    _chatSubscription?.cancel();
    if (_currentAiMessage != null) _handleGenerationFailure(_currentAiMessage!);
    _currentAiMessage = null;
    state = state.copyWith(isThinking: false, isStopping: false);
    _service.stopGeneration().catchError((e) {});
  }

  Future<void> stopGeneration() async {
    if (!_isGenerating) return;
    state = state.copyWith(isStopping: true);
    final stopFuture = Future.microtask(() => _forceStopGeneration());
    await stopFuture.timeout(const Duration(seconds: 2), onTimeout: _forceStopGeneration);
  }

  Future<void> clearMemory() async {
    if (_isGenerating) _forceStopGeneration();
    state = state.copyWith(isLoadingEngine: true);
    await _repo.clearHistory();
    try {
      // Pass empty history for a full wipe
      await _service.performSecureReset(history: []);
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
    } catch (e) {
      state = state.copyWith(isLoadingEngine: false, error: "Reset failed: $e");
    }
  }

  @override
  void dispose() {
    _proStatusSubscription?.cancel(); // Cancel subscription listener
    _timeoutTimer?.cancel();
    _chatSubscription?.cancel();
    super.dispose();
  }
}

extension FutureIgnore on Future {
  void ignore() {}
}