import 'dart:async';
import 'package:fiveyear/data/app_settings_provider.dart';
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

  bool _isSnackbarVisible = false;
  String _snackbarMessage = "";
  Color? _snackbarColor; // Nullable, defaults to inverseSurface in build
  Timer? _snackbarTimer;
  bool _isLicenseDialogOpen = false;

  void _showTopSnackbar(String message, {Color? color}) {
    setState(() {
      _snackbarMessage = message;
      // If color is null, we will handle the default in the build method
      // or pass the specific scheme color here.
      _snackbarColor = color; 
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

  // Maps memory usage to semantic theme colors
  Color _getMemoryColor(double usage, ColorScheme s) {
    if (usage < 0.6) return s.primary;
    if (usage < 0.8) return s.tertiary; // Warning level
    return s.error; // Critical level
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final notifier = ref.read(chatControllerProvider.notifier);
    final settingsAsync = ref.watch(appSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Handle License Dialog
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

    // Handle Wakelock
    if (state.isDownloading) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    // Handle Errors
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTopSnackbar(state.error!, color: colorScheme.error);
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
                _showTopSnackbar('Memory cleared and reset.', color: colorScheme.primary);
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
                      _getMemoryColor(state.memoryPercentage, colorScheme),
                    ),
                  ),
                ),
              Expanded(
                child: _buildMainContent(state, notifier, isDark, colorScheme),
              ),
              _buildBottomArea(state, notifier, colorScheme),
            ],
          ),
          
          // Snackbar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: _isSnackbarVisible ? 0 : -60,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              // Default to inverseSurface if no specific color (like error) was passed
              color: _snackbarColor ?? colorScheme.inverseSurface,
              child: Center(
                child: Text(
                  _snackbarMessage,
                  style: TextStyle(
                    // If background is error, use onError. If inverseSurface, use onInverseSurface.
                    color: _snackbarColor == colorScheme.error 
                        ? colorScheme.onError 
                        : colorScheme.onInverseSurface,
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
            title: Text("Model License ${settingsAsync.value?.isModelLicenseAccepted ?? ''}"),
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

  Widget _buildMainContent(ChatState state, ChatController notifier, bool isDark, ColorScheme colorScheme) {
    if (state.isCheckingForModel) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.needsDownload || state.isDownloading) {
      return _buildIntroUI(state, notifier, isDark, colorScheme);
    }
    if (state.isLoadingEngine) {
      return _buildCenteredMessage(
        "Waking up...",
        isDark ? 'assets/icons/greyscale_night.png' : 'assets/icons/greyscale.png',
        colorScheme,
        showSpinner: true,
      );
    }
    return _buildChatList(state, isDark, colorScheme);
  }

  Widget _buildIntroUI(ChatState state, ChatController notifier, bool isDark, ColorScheme colorScheme) {
    String img = isDark ? 'assets/icons/greyscale_night.png' : 'assets/icons/greyscale.png';
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Image.asset(img, width: 180, errorBuilder: (_, __, ___) => Icon(Icons.smart_toy, size: 100, color: colorScheme.primary)),
            const SizedBox(height: 32),
            Text("Let's get set up", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            Text(
              "To keep your thoughts private, I need to download a 'digital brain' once.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 40),
            _buildProgressButton(state, notifier, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton(ChatState state, ChatController notifier, ColorScheme colorScheme) {
    final double percentage = state.downloadProgress;
    final bool isDownloading = state.isDownloading;
    
    // Background of the button (unfilled portion)
    final bgColor = colorScheme.primaryContainer.withOpacity(0.3);
    // Border color
    final borderColor = colorScheme.primary;
    // Fill color (progress)
    final fillColor = colorScheme.primaryContainer;
    // Text Color
    final textColor = colorScheme.primary;

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Stack(
        children: [
          if (isDownloading)
            LayoutBuilder(builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth * percentage,
                decoration: BoxDecoration(
                  color: fillColor,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


Widget _buildChatList(ChatState state, bool isDark, ColorScheme colorScheme) {
    final messages = state.messages;

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
                      Icon(Icons.chat_bubble_outline, size: 100, color: colorScheme.outline),
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


  Widget _buildBottomArea(ChatState state, ChatController notifier, ColorScheme colorScheme) {
    if (state.isLoadingEngine || state.isDownloading || state.needsDownload || state.isCheckingForModel) {
      return const SizedBox.shrink();
    }

    void attemptSend() {
      final text = _textController.text;
      if (text.trim().isEmpty) return;
      if (state.isMemoryFull) {
        _showTopSnackbar("Memory full! Please clear chat.", color: colorScheme.error);
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
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              cursorColor: colorScheme.primary,
              decoration: InputDecoration(
                hintText: hintText,
                filled: true,
                // Solid input background
                fillColor: colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              onSubmitted: (_) => attemptSend(),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 26,
            backgroundColor: (state.isThinking || state.isStopping)
                ? colorScheme.surfaceContainerHighest
                : (state.isMemoryFull ? colorScheme.errorContainer : colorScheme.primary),
            child: state.isStopping 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSurface)))
              : IconButton(
                  icon: state.isThinking 
                      ? Icon(Icons.stop_rounded, color: colorScheme.onSurface)
                      : Icon(state.isMemoryFull ? Icons.delete_outline : Icons.arrow_upward, 
                          color: state.isMemoryFull ? colorScheme.onErrorContainer : colorScheme.onPrimary),
                  onPressed: state.isThinking
                      ? notifier.stopGeneration
                      : state.isMemoryFull
                          ? () async {
                              await notifier.clearMemory();
                              _showTopSnackbar('Memory cleared!', color: colorScheme.primary);
                            }
                          : attemptSend,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredMessage(String text, String asset, ColorScheme colorScheme, {bool showSpinner = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: 0.4, child: Image.asset(asset, width: 140, errorBuilder: (_, __, ___) => SizedBox(height: 140, child: Icon(Icons.smart_toy, size: 80, color: colorScheme.secondary)))),
            const SizedBox(height: 24),
            if (showSpinner) ...[
              CircularProgressIndicator(color: colorScheme.primary), 
              const SizedBox(height: 16)
            ],
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
    
    // Bubble Colors
    final bubbleColor = isUser 
        ? colorScheme.primary 
        : colorScheme.surfaceContainerHighest; 
        
    final textColor = isUser 
        ? colorScheme.onPrimary 
        : colorScheme.onSurface;
        
    // Link Colors: Needs high contrast against the bubble background
    final linkColor = isUser 
        ? colorScheme.onPrimaryContainer // Or a light variant if primary is dark
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
                code: TextStyle(backgroundColor: colorScheme.surface.withOpacity(0.5), color: textColor, fontFamily: 'monospace', fontSize: 14),
                codeblockDecoration: BoxDecoration(color: colorScheme.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
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