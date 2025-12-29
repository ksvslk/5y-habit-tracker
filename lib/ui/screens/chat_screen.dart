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

  static const Color emeraldStroke = Color(0xFF064E3B);
  static const Color seafoamBg = Color(0xFFECFDF5);
  static const Color progressGreen = Color(0xFF10B981);
  static const Color mintLight = Color(0xFFD1FAE5);
  static const Color warningYellow = Color(0xFFFBBF24);
  static const Color dangerRed = Color(0xFFEF4444);

  bool _isSnackbarVisible = false;
  String _snackbarMessage = "";
  Color _snackbarColor = Colors.black87;
  Timer? _snackbarTimer;

  void _showTopSnackbar(String message, {Color? color}) {
    setState(() {
      _snackbarMessage = message;
      _snackbarColor = color ?? (Theme.of(context).brightness == Brightness.dark 
          ? Colors.grey[800]! 
          : Colors.black87);
      _isSnackbarVisible = true;
    });
    _snackbarTimer?.cancel();
    _snackbarTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isSnackbarVisible = false;
        });
      }
    });
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

    if (state.isDownloading) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    // --- FIX: Listen for Errors and Trigger Snackbar ---
    // If the controller reports an error (like Memory Full), show it and clear it.
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTopSnackbar(state.error!, color: dangerRed);
        notifier.clearError(); // Prevent infinite loop
      });
    }

    final bool isReady = !state.isLoadingEngine && 
                         !state.isDownloading && 
                         !state.needsDownload && 
                         !state.isCheckingForModel;

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
              if (isReady)
                SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: state.memoryPercentage,
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getMemoryColor(state.memoryPercentage),
                    ),
                  ),
                ),
              Expanded(
                child: _buildMainContent(state, notifier, isDark, primaryColor),
              ),
              _buildBottomArea(state, notifier, isDark, primaryColor),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: _isSnackbarVisible ? 0 : -60,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              color: _snackbarColor,
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

  Widget _buildMainContent(ChatState state, ChatController notifier, bool isDark, Color color) {
    if (state.isCheckingForModel) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.needsDownload || state.isDownloading) {
      return _buildIntroUI(state, notifier, isDark);
    }
    if (state.isLoadingEngine) {
      return _buildCenteredMessage(
        isDark,
        "Waking up...",
        isDark ? 'assets/icons/greyscale_night.png' : 'assets/icons/greyscale.png',
        showSpinner: true,
      );
    }
    return _buildChatList(state, isDark, color);
  }

  Widget _buildIntroUI(ChatState state, ChatController notifier, bool isDark) {
    String img = isDark ? 'assets/icons/greyscale_night.png' : 'assets/icons/greyscale.png';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Image.asset(img, width: 180, errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, size: 100)),
            const SizedBox(height: 32),
            const Text("Let's get set up", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(
              "To keep your thoughts private, I need to download a 'digital brain' once.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 40),
            _buildProgressButton(state, notifier, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton(ChatState state, ChatController notifier, bool isDark) {
    final double percentage = state.downloadProgress;
    final bool isDownloading = state.isDownloading;
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : seafoamBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? progressGreen : emeraldStroke, width: 2),
      ),
      child: Stack(
        children: [
          if (isDownloading)
            LayoutBuilder(builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth * percentage,
                decoration: BoxDecoration(
                  color: isDark ? progressGreen.withOpacity(0.3) : mintLight,
                  borderRadius: BorderRadius.circular(18),
                ),
              );
            }),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isDownloading ? null : notifier.downloadAndStart,
              child: Center(
                child: Text(
                  isDownloading ? "Downloading ${(percentage * 100).round()}%" : "Start Setup",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? mintLight : emeraldStroke),
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
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.4,
                child: Image.asset(
                  isDark ? 'assets/icons/greyscale_night.png' : 'assets/icons/greyscale.png',
                  width: 140,
                  errorBuilder: (_, __, ___) => const Icon(Icons.chat_bubble_outline, size: 100),
                ),
              ),
              const SizedBox(height: 24),
              Text("Unload Your thoughts...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final message = messages[i];

        // --- FIX START ---
        // Check if this is an AI message that is empty AND the AI has stopped thinking.
        // If so, we hide it completely so the 3-dot bubble doesn't persist.
        final isStoppedEmptyResponse = !message.isUser && 
                                       message.content.value.isEmpty && 
                                       !state.isThinking;

        if (isStoppedEmptyResponse) {
          return const SizedBox.shrink();
        }
        // --- FIX END ---

        return _Bubble(message: message, isDark: isDark, color: color);
      },
    );
  }

  Widget _buildBottomArea(ChatState state, ChatController notifier, bool isDark, Color color) {
    if (state.isLoadingEngine || state.isDownloading || state.needsDownload || state.isCheckingForModel) {
      return const SizedBox.shrink();
    }

    void attemptSend() {
      final text = _textController.text;
      if (text.trim().isEmpty) return;
      
      // We still check visually here, but the real logic is now in the controller
      if (state.isMemoryFull) {
        _showTopSnackbar("Memory full! Please clear chat.", color: dangerRed);
        return;
      }
      
      _textController.clear();
      notifier.sendMessage(text);
    }

    String hintText = "Type a message...";
    if (state.isStopping) hintText = "Stopping...";
    else if (state.isThinking) hintText = "Thinking...";
    else if (state.isMemoryFull) hintText = "Memory Full - Clear to continue";

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !state.isThinking && !state.isStopping && !state.isMemoryFull,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: hintText,
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => attemptSend(),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 26,
            backgroundColor: (state.isThinking || state.isStopping)
                ? (isDark ? Colors.white12 : Colors.black12)
                : (state.isMemoryFull ? dangerRed.withOpacity(0.2) : color),
            child: state.isStopping 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black)))
              : IconButton(
                  icon: state.isThinking 
                      ? Icon(Icons.stop_rounded, color: isDark ? Colors.white : Colors.black)
                      : Icon(state.isMemoryFull ? Icons.delete_outline : Icons.arrow_upward, 
                          color: state.isMemoryFull ? dangerRed : (isDark ? Colors.black : Colors.white)),
                  onPressed: state.isThinking
                      ? notifier.stopGeneration
                      : state.isMemoryFull
                          ? () async {
                              await notifier.clearMemory();
                              _showTopSnackbar('Memory cleared!');
                            }
                          : attemptSend,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredMessage(bool isDark, String text, String asset, {bool showSpinner = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: 0.4, child: Image.asset(asset, width: 140, errorBuilder: (_, __, ___) => const SizedBox(height: 140))),
            const SizedBox(height: 24),
            if (showSpinner) ...[const CircularProgressIndicator(), const SizedBox(height: 16)],
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey, letterSpacing: 0.5)),
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

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final Color color;

  const _Bubble({required this.message, required this.isDark, required this.color});

  Future<void> _launchUrl(String urlString) async {
    final Uri? url = Uri.tryParse(urlString.trim());
    if (url != null && await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    bool isUser = message.isUser;
    final bubbleColor = isUser ? color : (isDark ? Colors.white12 : Colors.black.withOpacity(0.05));
    final textColor = isUser ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white : Colors.black);
    final linkColor = isUser ? (isDark ? Colors.black87 : Colors.white70) : Colors.blueAccent;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
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
            String text = rawText.replaceAll(r'\n', '\n\n');
            if (!isUser && text.isEmpty) return TypingIndicator(isDark: isDark);
            return MarkdownBody(
              data: text, selectable: true, softLineBreak: true,
              extensionSet: md.ExtensionSet.gitHubWeb,
              onTapLink: (text, href, title) { if (href != null) _launchUrl(href); },
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 16, color: textColor),
                strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
                a: TextStyle(color: linkColor, decoration: TextDecoration.underline),
                code: TextStyle(backgroundColor: isDark ? Colors.black26 : Colors.white54, color: textColor, fontFamily: 'monospace', fontSize: 14),
                codeblockDecoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                blockquote: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: isDark ? Colors.white30 : Colors.black26, width: 4))),
              ),
            );
          },
        ),
      ),
    );
  }
}