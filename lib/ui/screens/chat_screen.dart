// (Imports remain the same)
import 'dart:async';
import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/services/chat_controller.dart';
import 'package:fiveyear/ui/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // Import for Paywall
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
  bool _isLicenseDialogOpen = false;

  void _showTopSnackbar(String message, {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    setState(() {
      _snackbarMessage = message;
      _snackbarColor = color ?? colorScheme.inverseSurface;
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
    final settingsAsync = ref.watch(appSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (settingsAsync.hasValue) {
      final settings = settingsAsync.value!;
      final bool isModelReady = !state.isLoadingEngine && 
                                !state.isDownloading && 
                                !state.needsDownload && 
                                !state.isCheckingForModel;

      if (isModelReady && !settings.isModelLicenseAccepted && !_isLicenseDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLicenseDialog(context);
        });
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isDownloading) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTopSnackbar(state.error!, color: dangerRed);
        notifier.clearError(); 
      });
    }

    final bool isReady = !state.isLoadingEngine && 
                         !state.isDownloading && 
                         !state.needsDownload && 
                         !state.isCheckingForModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device AI'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getMemoryColor(state.memoryPercentage),
                    ),
                  ),
                ),
              Expanded(
                child: _buildMainContent(state, notifier, isDark),
              ),
              _buildBottomArea(state, notifier, isDark),
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
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
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

  // (License Dialog and Main Content Helpers remain the same)
  void _showLicenseDialog(BuildContext context) {
   setState(() => _isLicenseDialogOpen = true);
    final settingsAsync = ref.watch(appSettingsProvider);

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return PopScope(
          canPop: false, 
          child: AlertDialog(
            title: Text("Model License"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "To use this offline AI model, you must agree to the Llama Community License terms.",
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://ai.google.dev/gemma/terms'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        "Read License Agreement",
                        style: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () async {
                  await ref.read(appSettingsRepositoryProvider)
                      .setModelLicenseAccepted(true);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("I Accept"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(ChatState state, ChatController notifier, bool isDark) {
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
    return _buildChatList(state, isDark);
  }

  Widget _buildIntroUI(ChatState state, ChatController notifier, bool isDark) {
    String img = isDark ? 'assets/icons/greyscale_night.png' : 'assets/icons/greyscale.png';
    final colorScheme = Theme.of(context).colorScheme;
    
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
              style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant, height: 1.5),
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

  Widget _buildChatList(ChatState state, bool isDark) {
    final messages = state.messages;
    final colorScheme = Theme.of(context).colorScheme;

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
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
                "Unload Your thoughts",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Designed for reflection, not facts.\nWorks 100% offline – on-device.\nAccuracy may vary.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
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
        
        final isStoppedEmptyResponse = !message.isUser && 
                                       message.content.value.isEmpty && 
                                       !state.isThinking;

        if (isStoppedEmptyResponse) {
          return const SizedBox.shrink();
        }

        return _Bubble(message: message, isDark: isDark);
      },
    );
  }

  Widget _buildBottomArea(ChatState state, ChatController notifier, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoadingEngine || state.isDownloading || state.needsDownload || state.isCheckingForModel) {
      return const SizedBox.shrink();
    }

    // NEW: Handle send attempt with limit check
    Future<void> attemptSend() async {
      final text = _textController.text;
      if (text.trim().isEmpty) return;
      
      if (state.isMemoryFull) {
        _showTopSnackbar("Memory full! Please clear chat.", color: dangerRed);
        return;
      }

      // Check daily limit via UI state first for immediate feedback
      if (state.isDailyLimitReached) {
        await RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
        return;
      }

      _textController.clear();
      
      // Send message. If logic fails (returns false), trigger paywall
      final success = await notifier.sendMessage(text);
      if (!success) {
        // Restore text so user doesn't lose it
        _textController.text = text;
        await RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
      }
    }

    String hintText = "Type a message...";
    if (state.isStopping) hintText = "Stopping...";
    else if (state.isThinking) hintText = "Thinking...";
    else if (state.isMemoryFull) hintText = "Memory Full - Clear to continue";
    else if (state.isDailyLimitReached) hintText = "Daily limit reached. Tap to unlock.";

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: state.isDailyLimitReached 
                ? () => RevenueCatUI.presentPaywallIfNeeded("5Y Pro") 
                : null,
              child: AbsorbPointer(
                absorbing: state.isDailyLimitReached,
                child: TextField(
                  controller: _textController,
                  enabled: !state.isThinking && !state.isStopping && !state.isMemoryFull,
                  style: TextStyle(
                    fontSize: 16, 
                    color: state.isDailyLimitReached 
                        ? colorScheme.onSurface.withOpacity(0.5) 
                        : colorScheme.onSurface
                  ),
                  cursorColor: colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: hintText,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    // NEW: Lock icon inside input
                    suffixIcon: state.isDailyLimitReached 
                        ? const Icon(Icons.lock_outline, size: 20) 
                        : null,
                  ),
                  onSubmitted: (_) => attemptSend(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 26,
            backgroundColor: (state.isThinking || state.isStopping)
                ? colorScheme.surfaceContainerHighest
                : (state.isMemoryFull || state.isDailyLimitReached ? dangerRed.withOpacity(0.2) : colorScheme.primary),
            child: state.isStopping 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSurface)))
              : IconButton(
                  icon: state.isThinking 
                      ? Icon(Icons.stop_rounded, color: colorScheme.onSurface)
                      : Icon(
                          state.isMemoryFull ? Icons.delete_outline : 
                          state.isDailyLimitReached ? Icons.lock : Icons.arrow_upward, 
                          color: (state.isMemoryFull || state.isDailyLimitReached) ? dangerRed : colorScheme.onPrimary
                        ),
                  onPressed: state.isThinking
                      ? notifier.stopGeneration
                      : (state.isMemoryFull)
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: 0.4, child: Image.asset(asset, width: 140, errorBuilder: (_, __, ___) => const SizedBox(height: 140))),
            const SizedBox(height: 24),
            if (showSpinner) ...[const CircularProgressIndicator(), const SizedBox(height: 16)],
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
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

  const _Bubble({required this.message, required this.isDark});

  Future<void> _launchUrl(String urlString) async {
    final Uri? url = Uri.tryParse(urlString.trim());
    if (url != null && await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isUser = message.isUser;
    
    final bubbleColor = isUser 
        ? colorScheme.primary 
        : colorScheme.surfaceContainerHighest; 
        
    final textColor = isUser 
        ? colorScheme.onPrimary 
        : colorScheme.onSurface;
        
    final linkColor = isUser 
        ? colorScheme.onPrimary.withOpacity(0.8) 
        : colorScheme.primary;

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
                code: TextStyle(backgroundColor: colorScheme.surface, color: colorScheme.onSurface, fontFamily: 'monospace', fontSize: 14),
                codeblockDecoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(8)),
                blockquote: TextStyle(color: textColor.withOpacity(0.7), fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: textColor.withOpacity(0.3), width: 4))),
              ),
            );
          },
        ),
      ),
    );
  }
}