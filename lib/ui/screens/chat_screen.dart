import 'package:fiveyear/data/gemma_provider.dart';
import 'package:fiveyear/data/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// --- DATA MODELS & PROVIDERS ---

class ChatMessage {
  final ValueNotifier<String> textNotifier;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required String text, required this.isUser, DateTime? timestamp})
    : textNotifier = ValueNotifier(text),
      timestamp = timestamp ?? DateTime.now();

  void append(String token) => textNotifier.value += token;
}

class ChatHistoryNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatRepository _repository;
  bool _isLoadingHistory = false;

  ChatHistoryNotifier(this._repository) : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_isLoadingHistory) return; // Prevent duplicate loads
    _isLoadingHistory = true;

    try {
      // 1. Fetch from Repository
      final entities = await _repository.getHistory();

      // 2. Convert to UI Model
      final messages = entities
          .map(
            (e) => ChatMessage(
              text: e.text ?? "",
              isUser: e.isUser ?? false,
              timestamp: e.timestamp ?? DateTime.now(),
            ),
          )
          .toList();

      // 3. Set state only once
      state = messages;
    } finally {
      _isLoadingHistory = false;
    }
  }

  Future<void> addInteraction(ChatMessage userMsg, ChatMessage aiMsg) async {
    // Update UI immediately
    state = [aiMsg, userMsg, ...state];

    // Save User Message to DB
    await _repository.saveMessage(userMsg.textNotifier.value, true);
  }

  Future<void> saveAiResponse(ChatMessage aiMsg) async {
    // Save AI Message to DB
    await _repository.saveMessage(aiMsg.textNotifier.value, false);
  }

  Future<void> clear() async {
    state = [];
    await _repository.clearHistory();
  }
}

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatMessage>>((ref) {
      final repo = ref.watch(chatRepositoryProvider);
      return ChatHistoryNotifier(repo);
    });

// --- UI ---

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();

  static const Color emeraldStroke = Color(0xFF064E3B);
  static const Color seafoamBg = Color(0xFFECFDF5);
  static const Color progressGreen = Color(0xFF10B981);
  static const Color mintLight = Color(0xFFD1FAE5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInit();
    });
  }

  void _checkInit() {
    final state = ref.read(gemmaProvider);
    // Only init if we are NOT ready and NOT currently loading/downloading
    if (!state.isReady && !state.isLoading && !state.isDownloading) {
      ref.read(gemmaProvider.notifier).init();
    }
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    final userMsg = ChatMessage(text: text, isUser: true);
    final aiMsg = ChatMessage(text: "", isUser: false);

    await ref.read(chatHistoryProvider.notifier).addInteraction(userMsg, aiMsg);

    await for (final token
        in ref.read(gemmaProvider.notifier).sendMessage(text)) {
      aiMsg.append(token);
    }

    ref.read(chatHistoryProvider.notifier).saveAiResponse(aiMsg);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gemmaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;

    WakelockPlus.toggle(enable: state.isDownloading);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private AI'),
        actions: [
          // Clear Button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Clear Chat History",
            onPressed: () {
              ref.read(chatHistoryProvider.notifier).clear();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMainContent(state, isDark, color)),
          _buildBottomArea(state, isDark, color),
        ],
      ),
    );
  }

  Widget _buildMainContent(GemmaState state, bool isDark, Color color) {
    // Show error if present
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(gemmaProvider.notifier).downloadAndLoadModel();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // 1. If Ready -> Show Chat
    if (state.isReady) {
      return _buildChatList(isDark, color);
    }

    // 2. If checking for model -> Show minimal loading
    if (state.isCheckingForModel) {
      return _buildCenteredMessage(
        isDark,
        "Checking...",
        isDark
            ? 'assets/icons/greyscale_night.png'
            : 'assets/icons/greyscale.png',
        showSpinner: true,
      );
    }

    // 3. If Downloading -> Show Progress
    if (state.isDownloading) {
      return _buildIntroUI(state, isDark);
    }

    // 4. If Loading (Reading file into memory) -> Show Spinner
    if (state.isLoading) {
      return _buildCenteredMessage(
        isDark,
        "Waking up...",
        isDark
            ? 'assets/icons/greyscale_night.png'
            : 'assets/icons/greyscale.png',
        showSpinner: true,
      );
    }

    // 5. Default -> Show Intro (Start Setup)
    return _buildIntroUI(state, isDark);
  }

  Widget _buildCenteredMessage(
    bool isDark,
    String text,
    String asset, {
    bool showSpinner = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(opacity: 0.4, child: Image.asset(asset, width: 140)),
          const SizedBox(height: 24),
          if (showSpinner) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroUI(GemmaState state, bool isDark) {
    String img = isDark
        ? 'assets/icons/greyscale_night.png'
        : 'assets/icons/greyscale.png';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Image.asset(img, width: 180),
            const SizedBox(height: 32),
            const Text(
              "Let's get set up",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              "To keep your chats private, I need to download a 'digital brain' once. This takes a few minutes.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _buildProgressButton(state, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton(GemmaState state, bool isDark) {
    final double percentage = state.downloadProgress;
    final bool isDownloading = state.isDownloading;
    final int percentInt = (percentage * 100).round();

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : seafoamBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? progressGreen : emeraldStroke,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          if (isDownloading)
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth * percentage,
                  decoration: BoxDecoration(
                    color: isDark ? progressGreen.withOpacity(0.3) : mintLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                );
              },
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              // Disable button if we are doing anything active
              onTap: (state.isLoading || state.isDownloading)
                  ? null
                  : () =>
                        ref.read(gemmaProvider.notifier).downloadAndLoadModel(),
              child: Center(
                child: Text(
                  isDownloading ? "Downloading $percentInt%" : "Start Setup",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? mintLight : emeraldStroke,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(bool isDark, Color color) {
    final messages = ref.watch(chatHistoryProvider);

    if (messages.isEmpty) {
      return _buildCenteredMessage(
        isDark,
        "Ready. Use trash bin to clear chats or reset AI if needed.",
        isDark
            ? 'assets/icons/greyscale_night.png'
            : 'assets/icons/greyscale.png',
        showSpinner: false,
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, i) =>
          _Bubble(message: messages[i], isDark: isDark, color: color),
    );
  }

  Widget _buildBottomArea(GemmaState state, bool isDark, Color color) {
    if (!state.isReady) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: state.isReady,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: isDark
                    ? Colors.white10
                    : Colors.black.withOpacity(0.04),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 26,
            backgroundColor: state.isReady ? color : color.withOpacity(0.1),
            child: IconButton(
              icon: Icon(
                Icons.arrow_upward,
                color: isDark ? Colors.black : Colors.white,
              ),
              onPressed: state.isReady
                  ? () => _handleSubmitted(_textController.text)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _textController.dispose();
    super.dispose();
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final Color color;
  const _Bubble({
    required this.message,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    bool isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? color
              : (isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: ValueListenableBuilder(
          valueListenable: message.textNotifier,
          builder: (_, text, __) => Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: isUser
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white : Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}
