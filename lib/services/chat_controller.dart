import 'dart:async';

import 'package:fiveyear/data/chat_repository.dart';
import 'package:fiveyear/services/gemma_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _generalErrorMsg =
    "Something went wrong. Try hitting the trash bin icon and/or restarting the app.";

// --- 1. DATA MODEL ---
class ChatMessage {
  final ValueNotifier<String> content;
  final bool isUser;

  ChatMessage({required String text, required this.isUser})
    : content = ValueNotifier(text);

  void append(String token) => content.value += token;
}

// --- 2. STATE MODEL ---
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoadingEngine;
  final bool isDownloading;
  final double downloadProgress;
  final bool isThinking;

  final int usedTokens; // Tokens committed to history
  final int pendingInputTokens; // Tokens currently in the text field
  final int maxTokens;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoadingEngine = true,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.isThinking = false,
    this.usedTokens = 0,
    this.pendingInputTokens = 0,
    this.maxTokens = 1024,
    this.error,
  });

  // Real-time calculation for the UI progress bar
  int get totalProjectedTokens => usedTokens + pendingInputTokens;

  // Threshold check (buffer of 50 tokens)
  bool get isMemoryFull => totalProjectedTokens >= (maxTokens - 50);

  double get memoryPercentage => totalProjectedTokens / maxTokens;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoadingEngine,
    bool? isDownloading,
    double? downloadProgress,
    bool? isThinking,
    int? usedTokens,
    int? pendingInputTokens,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoadingEngine: isLoadingEngine ?? this.isLoadingEngine,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isThinking: isThinking ?? this.isThinking,
      usedTokens: usedTokens ?? this.usedTokens,
      pendingInputTokens: pendingInputTokens ?? this.pendingInputTokens,
      maxTokens: maxTokens,
      error: error,
    );
  }
}

// --- 3. PROVIDER ---
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    final service = ref.watch(gemmaServiceProvider);
    final repo = ref.watch(chatRepositoryProvider);
    return ChatController(service, repo);
  },
);

// --- 4. CONTROLLER LOGIC ---
class ChatController extends StateNotifier<ChatState> {
  final GemmaService _service;
  final ChatRepository _repo;
  StreamSubscription? _subscription; // 1. Add subscription handle
  bool _isSessionDirty = false;


  ChatController(this._service, this._repo) : super(ChatState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Load History & Estimate Tokens
    final history = await _repo.getHistory();
    final historyMsgs = history
        .map((e) => ChatMessage(text: e.text ?? "", isUser: e.isUser ?? false))
        .toList();

    int initialTokens = 50; // System prompt buffer
    for (var msg in historyMsgs) {
      initialTokens += (msg.content.value.length / 3).ceil();
    }

    state = state.copyWith(messages: historyMsgs, usedTokens: initialTokens);

    // 2. Check Model Status
    final isDownloaded = await _service.isModelDownloaded();

    if (isDownloaded) {
      await _bootUpAi();
    } else {
      state = state.copyWith(isLoadingEngine: false, isDownloading: false);
    }
  }

  Future<void> downloadAndStart() async {
    state = state.copyWith(isDownloading: true, error: null);
    try {
      await for (final progress in _service.downloadModel()) {
        state = state.copyWith(downloadProgress: progress);
      }
      await _bootUpAi();
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: "Download failed. Please try again.",
      );
    }
  }

  Future<void> _bootUpAi() async {
    state = state.copyWith(isLoadingEngine: true, isDownloading: false);
    try {
      await _service.loadEngine();
      await _service.startNewSession();
      state = state.copyWith(isLoadingEngine: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingEngine: false,
        error: "AI Init Failed. Please try again.",
      );
    }
  }

  /// Call this from TextField.onChanged to update the progress bar instantly
  void onTextChanged(String text) {
    if (text.isEmpty) {
      if (state.pendingInputTokens != 0) {
        state = state.copyWith(pendingInputTokens: 0);
      }
      return;
    }

    final estimated = (text.length / 3).ceil();
    state = state.copyWith(pendingInputTokens: estimated);
  }

  // 2. NEW: STOP METHOD
Future<void> stopGeneration() async {
    await _subscription?.cancel();
    _subscription = null;

    // 1. Mark session as dirty (It's now out of sync with UI)
    _isSessionDirty = true;

    final currentMessages = List<ChatMessage>.from(state.messages);

    if (currentMessages.isNotEmpty && !currentMessages.first.isUser) {
      final aiMsg = currentMessages.first;
      final partialText = aiMsg.content.value;

      if (partialText.isEmpty) {
        // Remove empty bubble
        currentMessages.removeAt(0); 
      } else {
        // Save partial text
        await _repo.saveMessage(partialText, false);
      }
    }

    state = state.copyWith(
      messages: currentMessages,
      isThinking: false,
    );
  }


  /// Helper to silently reset the engine context to match DB history
  Future<void> _refreshSession() async {
    try {
      // Don't show full loading screen, just a quick background reset
      await _service.startNewSession();
      _isSessionDirty = false;
    } catch (e) {
      print("Failed to refresh session: $e");
    }
  }


  // 3. UPDATED: SEND MESSAGE
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isThinking) return;

    // 2. SAFETY CHECK: If we stopped previously, refresh the brain first.
    if (_isSessionDirty) {
       // We set a temporary loading state or just wait
       // (Optional: You could show a tiny "Reconnecting..." indicator)
       await _refreshSession();
    }

    final inputTokens = (text.length / 3).ceil();
    final userMsg = ChatMessage(text: text, isUser: true);
    final aiMsg = ChatMessage(text: "", isUser: false);
    
    state = state.copyWith(
      messages: [aiMsg, userMsg, ...state.messages],
      isThinking: true,
      pendingInputTokens: 0,
      usedTokens: state.usedTokens + inputTokens,
    );
    
    await _repo.saveMessage(text, true);

    if (state.usedTokens >= (state.maxTokens - 50)) {
      aiMsg.content.value = "💭 My memory is full. Please tap the trash icon to clear.";
      await _repo.saveMessage(aiMsg.content.value, false);
      state = state.copyWith(isThinking: false);
      return; 
    }

    // 3. ERROR HANDLING WRAPPER
    try {
      _subscription = _service.streamResponse(text).listen(
        (token) {
          aiMsg.append(token);
          state = state.copyWith(usedTokens: state.usedTokens + 1);
        },
        onDone: () async {
          await _repo.saveMessage(aiMsg.content.value, false);
          state = state.copyWith(isThinking: false);
          _subscription = null;
        },
        onError: (e) async {
          // If we hit an error (like "Session Invalid"), handle it gracefully
          print("Stream error: $e");
          
          if (aiMsg.content.value.isEmpty) {
             // If it failed immediately, it might be a context error. 
             // We can try to auto-heal once.
             if (!_isSessionDirty) {
               _isSessionDirty = true;
               aiMsg.content.value = "⚠️ Connection slip. Please try sending again.";
             } else {
               aiMsg.content.value = "💭 I encountered an error.";
             }
          }
          await _repo.saveMessage(aiMsg.content.value, false);
          state = state.copyWith(isThinking: false);
          _subscription = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
       // Catch synchronous start-up errors
       print("Sync error: $e");
       state = state.copyWith(isThinking: false, error: "Could not start generation.");
    }
  }

Future<void> clearMemory() async {
    await stopGeneration();
    state = state.copyWith(messages: [], usedTokens: 50, pendingInputTokens: 0, isThinking: false);
    await _repo.clearHistory();
    await _refreshSession(); // Reuse the refresher
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Safety cleanup
    super.dispose();
  }
}
