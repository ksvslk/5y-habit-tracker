import 'dart:async';
import 'dart:io';
import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/data/app_settings_repository.dart';
import 'package:fiveyear/services/chat_controller.dart';
import 'package:fiveyear/ui/widgets/typing_indicator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
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
  final FocusNode _chatFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const Color progressGreen = Color(0xFF10B981);
  static const Color warningYellow = Color(0xFFFBBF24);
  static const Color dangerRed = Color(0xFFEF4444);

  bool _isSnackbarVisible = false;
  String _snackbarMessage = "";
  Color _snackbarColor = Colors.black87;
  Timer? _snackbarTimer;
  bool _isLicenseDialogOpen = false;

  @override
  void dispose() {
    WakelockPlus.disable();
    _textController.dispose();
    _chatFocusNode.dispose();
    _scrollController.dispose();
    _snackbarTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showTopSnackbar(String message, {Color? color}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    setState(() {
      _snackbarMessage = message;
      _snackbarColor = color ?? colorScheme.inverseSurface;
      _isSnackbarVisible = true;
    });
    _snackbarTimer?.cancel();
    _snackbarTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isSnackbarVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final notifier = ref.read(chatControllerProvider.notifier);
    final settingsAsync = ref.watch(appSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isThinking) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    if (settingsAsync.hasValue) {
      final settings = settingsAsync.value!;
      final bool isModelReady =
          !state.isLoadingEngine &&
          !state.isDownloading &&
          !state.needsDownload &&
          !state.isCheckingForModel;

      if (isModelReady &&
          !settings.isModelLicenseAccepted &&
          !_isLicenseDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showLicenseDialog(context),
        );
      }
    }

    if (state.isDownloading)
      WakelockPlus.enable();
    else
      WakelockPlus.disable();

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTopSnackbar(state.error!, color: dangerRed);
        notifier.clearError();
      });
    }

    // Determine if we show the setup screen or the chat screen
    final bool isSetupPhase =
        state.isCheckingForModel || state.isDownloading || state.needsDownload;
    final bool isReady = !isSetupPhase && !state.isLoadingEngine;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Disable default back button
        title: const Text('Private AI'), // Updated title
        leading: isReady // This will be the "edit button" (delete in this case)
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await notifier.clearMemory();
                  _showTopSnackbar('Memory cleared.');
                },
              )
            : null, // No leading widget if not ready
        actions: [
          IconButton( // This will be the "back button"
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (isReady) ...[
                SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: state.memoryPercentage,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      state.memoryPercentage < 0.6
                          ? progressGreen
                          : state.memoryPercentage < 0.8
                          ? warningYellow
                          : dangerRed,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: _buildMainContent(state, isDark, notifier, isSetupPhase),
              ),
              // Ensure input is only visible when completely ready
              if (isReady) _buildBottomArea(state, notifier),
            ],
          ),
          _buildAnimatedSnackbar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    ChatState state,
    bool isDark,
    ChatController notifier,
    bool isSetupPhase,
  ) {
    if (state.isCheckingForModel)
      return const Center(child: CircularProgressIndicator());
    if (isSetupPhase) return _buildIntroUI(state, notifier, isDark);
    if (state.isLoadingEngine)
      return _buildCenteredMessage(isDark, "Waking up...", showSpinner: true);

    if (state.messages.isEmpty) return _buildEmptyState(isDark);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length,
      itemBuilder: (context, i) {
        final message = state.messages[i];
        return RepaintBoundary(
          key: ValueKey(message.id),
          child: _Bubble(message: message, isDark: isDark),
        );
      },
    );
  }

  Widget _buildBottomArea(ChatState state, ChatController notifier) {
    final colorScheme = Theme.of(context).colorScheme;

    Future<void> handleSend() async {
      final text = _textController.text.trim();
      if (text.isEmpty || state.isThinking) return;

      if (state.isDailyLimitReached) {
        await RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
        return;
      }

      _textController.clear();
      _chatFocusNode.requestFocus(); // Focus persistence
      _scrollToBottom();

      await notifier.sendMessage(text);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _chatFocusNode,
              enabled: !state.isStopping && !state.isMemoryFull,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => handleSend(),
              decoration: InputDecoration(
                hintText: state.isThinking
                    ? "Thinking..."
                    : "Type a message...",
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: state.isDailyLimitReached
                    ? const Icon(Icons.lock_outline)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: state.isThinking
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primary,
            child: IconButton(
              icon: Icon(
                state.isThinking ? Icons.stop : Icons.arrow_upward,
                color: state.isThinking
                    ? colorScheme.onSurface
                    : colorScheme.onPrimary,
              ),
              onPressed: state.isThinking
                  ? notifier.stopGeneration
                  : handleSend,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroUI(ChatState state, ChatController notifier, bool isDark) {
    final img = isDark
        ? 'assets/icons/greyscale_night.png'
        : 'assets/icons/greyscale.png';
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
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
              "To keep your thoughts private, I need to download a 'digital brain' once.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _buildProgressButton(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton(ChatState state, ChatController notifier) {
    final colorScheme = Theme.of(context).colorScheme;
    final double percentage = state.downloadProgress;
    final bool isDownloading = state.isDownloading;

    final String label = isDownloading
        ? "Downloading ${(percentage * 100).round()}%"
        : "Start Setup";

    const textStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    return Container(
      width: double.infinity,
      height: 60,
      // clipBehavior: Clip.antiAlias is CRITICAL here.
      // It forces the internal children (the square blue bar) to follow the BorderRadius.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colorScheme.primary, width: 2),
      ),
      child: InkWell(
        onTap: isDownloading ? null : notifier.downloadAndStart,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final progressWidth = width * percentage;

            return Stack(
              children: [
                // 1. BOTTOM LAYER: The "Base" Text (Primary color)
                // Visible only when the progress bar hasn't reached it yet.
                Center(
                  child: Text(
                    label,
                    style: textStyle.copyWith(color: colorScheme.primary),
                  ),
                ),

                // 2. TOP LAYER: The "Filled" Block (Blue Bar + White Text)
                if (isDownloading)
                  ClipRect(
                    clipper: _ProgressClipper(progressWidth),
                    child: Stack(
                      children: [
                        // The blue background bar
                        Container(
                          width: width,
                          height: double.infinity,
                          color: colorScheme.primary,
                        ),
                        // The white text (Exact same position as the bottom text)
                        Center(
                          child: Text(
                            label,
                            style: textStyle.copyWith(
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showLicenseDialog(BuildContext context) {
    // 1. IMMEDIATELY set this to true so the build method
    // doesn't trigger a second dialog while this one is opening.
    setState(() => _isLicenseDialogOpen = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text("Model License${Platform.isIOS ? ' & Terms' : ''}"),
          content: RichText(
            text: TextSpan(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium, // Match dialog text style
              children: [
                const TextSpan(
                  text: "To use this offline AI model, you must agree to the ",
                ),
                TextSpan(
                  text: "Google Gemma terms",
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                      Uri.parse('https://ai.google.dev/gemma/terms'),
                    ),
                ),
           
                const TextSpan(text: ". "),
                TextSpan(text: "${Platform.isIOS ? 'Please read also our ' : ''}"),
                TextSpan(
                  text: "${Platform.isIOS ? 'EULA' : ''}",
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () =>
                        launchUrl(Uri.parse('https://indest.ee/eula-for-5y')),
                ),
                TextSpan(text: "${Platform.isIOS ? ' for assurance. ' : ''}"),
                const TextSpan(text: "Optionally see the "),
                TextSpan(
                  text: "Model Card",
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                      Uri.parse(
                        'https://ai.google.dev/gemma/docs/core/model_card_3',
                      ),
                    ),
                ),
                const TextSpan(text: "."),

              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Update the database/settings
                await ref
                    .read(appSettingsRepositoryProvider)
                    .setModelLicenseAccepted(true);

                if (context.mounted) {
                  // Use the navigator to pop the dialog
                  Navigator.of(context).pop();

                  // We keep _isLicenseDialogOpen true to prevent it
                  // re-popping during the transition to the chat screen
                }
              },
              child: const Text("I Accept"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredMessage(
    bool isDark,
    String text, {
    bool showSpinner = false,
    String? title,
  }) {
    final asset = isDark
        ? 'assets/icons/greyscale_night.png'
        : 'assets/icons/greyscale.png';
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
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
          if (title != null) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return _buildCenteredMessage(
      isDark,
      "Works 100% offline – on-device.\nReflection only. Not medical advice.\nMemory not saved. Clear with trash bin.",
      title: "Unload Your thoughts",
    );
  }

  Widget _buildAnimatedSnackbar(ColorScheme colorScheme) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: _isSnackbarVisible ? 0 : -60,
      left: 0,
      right: 0,
      child: Container(
        height: 50,
        color: _snackbarColor,
        alignment: Alignment.center,
        child: Text(
          _snackbarMessage,
          style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  const _Bubble({required this.message, required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: message.content,
          builder: (context, text, _) {
            if (!isUser && text.isEmpty) return TypingIndicator(isDark: isDark);
            return MarkdownBody(
              data: text.replaceAll(r'\n', '\n\n'),
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                  fontSize: 16,
                  height: 1.4,
                ),
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isUser ? colorScheme.onPrimary : colorScheme.primary,
                ),
                blockquote: TextStyle(
                  color:
                      (isUser ? colorScheme.onPrimary : colorScheme.onSurface)
                          .withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color:
                          (isUser ? colorScheme.onPrimary : colorScheme.primary)
                              .withOpacity(0.3),
                      width: 3,
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

class _ProgressClipper extends CustomClipper<Rect> {
  final double width;
  const _ProgressClipper(this.width);
  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, width, size.height);
  @override
  bool shouldReclip(covariant _ProgressClipper oldClipper) =>
      width != oldClipper.width;
}
