import 'dart:async';
import 'package:fiveyear/services/chat_controller.dart';
import 'package:fiveyear/ui/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:markdown/markdown.dart' as md;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();

  // --- OLD LAYOUT CONSTANTS ---
  static const Color emeraldStroke = Color(0xFF064E3B);
  static const Color seafoamBg = Color(0xFFECFDF5);
  static const Color progressGreen = Color(0xFF10B981);
  static const Color mintLight = Color(0xFFD1FAE5);
  static const Color warningYellow = Color(0xFFFBBF24);
  static const Color dangerRed = Color(0xFFEF4444);

  // --- TOP SNACKBAR STATE ---
  bool _isSnackbarVisible = false;
  String _snackbarMessage = "";
  Timer? _snackbarTimer;

  @override
  void initState() {
    super.initState();
    // No explicit init needed; Controller inits itself.
  }

  void _showTopSnackbar(String message) {
    setState(() {
      _snackbarMessage = message;
      _isSnackbarVisible = true;
    });
    _snackbarTimer?.cancel();
    _snackbarTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isSnackbarVisible = false;
        });
      }
    });
  }

  void _handleSubmitted(ChatController notifier) {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    _textController.clear();
    notifier.sendMessage(text);
  }

  Color _getMemoryColor(double usage) {
    if (usage < 0.6) return progressGreen;
    if (usage < 0.8) return warningYellow;
    return dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final notifier = ref.read(chatControllerProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;

    // Wakelock logic
    if (state.isDownloading)
      WakelockPlus.enable();
    else
      WakelockPlus.disable();

    // Mapping 'Ready' state from new controller
    final bool isReady =
        !state.isLoadingEngine && !state.isDownloading && state.error == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device AI'),
        actions: [
          if (isReady)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "Clear All",
              onPressed: () async {
                await notifier.clearMemory();
                _showTopSnackbar('Memory cleared and reset.');
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. MEMORY BAR (Restored Style)
              if (isReady)
                SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: state.memoryPercentage,
                    backgroundColor: isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getMemoryColor(state.memoryPercentage),
                    ),
                  ),
                ),

              // 2. MAIN CONTENT AREA
              Expanded(
                child: _buildMainContent(state, notifier, isDark, primaryColor),
              ),

              // 3. BOTTOM INPUT AREA (Restored Style)
              _buildBottomArea(state, notifier, isDark, primaryColor),
            ],
          ),

          // 4. CUSTOM TOP SNACKBAR
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: _isSnackbarVisible ? 0 : -60, // Slide in from top
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              color: isDark ? Colors.grey[800] : Colors.black87,
              child: Center(
                child: Text(
                  _snackbarMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    ChatState state,
    ChatController notifier,
    bool isDark,
    Color color,
  ) {
    if (state.error != null) {
      return Center(
        // FIX: Wrap in SingleChildScrollView here too
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: notifier.downloadAndStart, // Retry logic
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Logic to mimic old "Intro UI" vs "Chat UI"
    if (state.isLoadingEngine) {
      return _buildCenteredMessage(
        isDark,
        "Waking up...",
        isDark
            ? 'assets/icons/greyscale_night.png'
            : 'assets/icons/greyscale.png', // Ensure you have these assets or replace
        showSpinner: true,
      );
    }

    if (state.isDownloading) {
      return _buildIntroUI(state, notifier, isDark);
    }

    // If no history and model not loaded (should generally not happen due to auto-load in controller,
    // but useful for 'fresh install' state if controller logic changes)
    if (!state.isLoadingEngine &&
        state.messages.isEmpty &&
        state.usedTokens <= 50) {
      // In the new controller, 'usedTokens <= 50' implies empty history roughly.
      // However, controller auto-starts session.
      // We can just show the chat list (which handles empty state).
    }

    return _buildChatList(state, isDark, color);
  }

  Widget _buildIntroUI(ChatState state, ChatController notifier, bool isDark) {
    String img = isDark
        ? 'assets/icons/greyscale_night.png'
        : 'assets/icons/greyscale.png';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            // Safe image loading or fallback
            Image.asset(
              img,
              width: 180,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.smart_toy, size: 100),
            ),
            const SizedBox(height: 32),
            const Text(
              "Let's get set up",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              "To keep your thoughts private, I need to download a 'digital brain' once. This takes a few minutes.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _buildProgressButton(state, notifier, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton(
    ChatState state,
    ChatController notifier,
    bool isDark,
  ) {
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
              onTap: isDownloading ? null : notifier.downloadAndStart,
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

  Widget _buildChatList(ChatState state, bool isDark, Color color) {
    final messages = state.messages;

    if (messages.isEmpty) {
      // FIX: Added SingleChildScrollView here.
      // This allows the logo/text to scroll when the keyboard squeezes the screen.
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.4,
                child: Image.asset(
                  isDark
                      ? 'assets/icons/greyscale_night.png'
                      : 'assets/icons/greyscale.png',
                  width: 140,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.chat_bubble_outline, size: 100),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Unload Your thoughts as...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                ".. they are NOT sent to servers 🕵️\nThe colored bar shows memory usage.\nYou will need to reset at some point.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    // Normal Chat List (Already scrollable, so this is fine)
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, i) =>
          _Bubble(message: messages[i], isDark: isDark, color: color),
    );
  }

  Widget _buildBottomArea(ChatState state, ChatController notifier, bool isDark, Color color) {
    if (state.isLoadingEngine || state.isDownloading) return const SizedBox.shrink();

    void attemptSend() {
      if (state.isMemoryFull) {
        _showTopSnackbar("Memory full! Please clear chat to continue.");
        return;
      }
      _handleSubmitted(notifier);
    }

    // New: Handle Stop Logic
    void handleStop() {
      // Assuming your controller has a stop/cancel method. 
      // If not, we can add a simple one or just reset the thinking state.
      notifier.stopGeneration(); 
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !state.isThinking, 
              style: const TextStyle(fontSize: 16),
              onChanged: notifier.onTextChanged,
              decoration: InputDecoration(
                hintText: state.isThinking 
                    ? "Thinking..." 
                    : (state.isMemoryFull ? "Memory Full" : "Type a message..."),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => attemptSend(),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 26,
            // If thinking, we want the button to be active (Red/visible) so user can click stop
            backgroundColor: state.isThinking 
                ? (isDark ? Colors.white12 : Colors.black12) // Subtle background for stop
                : (state.isMemoryFull ? color.withOpacity(0.1) : color),
            child: IconButton(
              // CHANGE 1: Icon Logic
              icon: state.isThinking 
                ? Icon(Icons.stop_rounded, color: isDark ? Colors.white : Colors.black) // STOP ICON
                : Icon(
                    Icons.arrow_upward,
                    color: state.isMemoryFull 
                        ? (isDark ? Colors.grey : Colors.grey) 
                        : (isDark ? Colors.black : Colors.white),
                  ),
              // CHANGE 2: Action Logic
              onPressed: state.isThinking
                  ? handleStop // Call stop when thinking
                  : () => attemptSend(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredMessage(
    bool isDark,
    String text,
    String asset, {
    bool showSpinner = false,
  }) {
    // FIX: Added SingleChildScrollView here as well.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.4,
              child: Image.asset(
                asset,
                width: 140,
                errorBuilder: (_, __, ___) => const SizedBox(height: 140),
              ),
            ),
            const SizedBox(height: 24),
            if (showSpinner) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _textController.dispose();
    _snackbarTimer?.cancel();
    super.dispose();
  }
}

// --- BUBBLE WIDGET (RESTORED) ---
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final Color color;

  const _Bubble({
    super.key,
    required this.message,
    required this.isDark,
    required this.color,
  });

  /// Launch URLs safely
  Future<void> _launchUrl(String urlString) async {
    // 1. Sanitize the URL string (trim whitespace)
    final Uri? url = Uri.tryParse(urlString.trim());

    // 2. Rigorous null checking
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch url: $urlString");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isUser = message.isUser;

    // Background color logic
    final bubbleColor = isUser
        ? color
        : (isDark ? Colors.white12 : Colors.black.withOpacity(0.05));

    // Text color logic
    final textColor = isUser
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);

    // Link color logic (Make links pop against the background)
    final linkColor = isUser
        ? (isDark ? Colors.black87 : Colors.white70) // User bubble
        : Colors.blueAccent; // AI bubble

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ), // Limit width
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: ValueListenableBuilder(
          valueListenable: message.content,
          builder: (_, rawText, __) {
            // --- THE FIX ---
            // 1. Replace literal '\n' sequences with actual newlines.
            // 2. Replace literal '\\' sequences with a single backslash.
            String text = rawText.replaceAll(r'\n', '\n\n');

            // Typing indicator logic
            if (!isUser && text.isEmpty) {
              return TypingIndicator(isDark: isDark);
            }

            // --- MARKDOWN WIDGET ---
            return MarkdownBody(
              data: text,
              selectable: true, // Allows user to copy text
              softLineBreak: true,
              extensionSet: md.ExtensionSet.gitHubWeb,

              // Handle Link Clicks
              onTapLink: (text, href, title) {
                if (href != null) _launchUrl(href);
              },

              // Style the Markdown
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 16, color: textColor), // Normal text
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ), // **Bold**
                em: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: textColor,
                ), // *Italic*
                a: TextStyle(
                  color: linkColor,
                  decoration: TextDecoration.underline,
                ), // Links
                // Code blocks styling
                code: TextStyle(
                  backgroundColor: isDark ? Colors.black26 : Colors.white54,
                  color: textColor,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                codeblockDecoration: BoxDecoration(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                blockquote: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isDark ? Colors.white30 : Colors.black26,
                      width: 4,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
