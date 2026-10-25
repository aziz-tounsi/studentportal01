import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../../data/services/ai_data_provider.dart';
import '../../../data/services/ai_service.dart';
import '../../providers/nav_bar_provider.dart';
import '../../widgets/ios_loader.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const Color _pink = Color(0xFFFF2D78);
const Color _pinkLight = Color(0xFFFF5CA0);
const String _openRouterApiKey = String.fromEnvironment(
  'OPENROUTER_API_KEY',
  defaultValue: kDefaultOpenRouterApiKey,
);

// Free OpenRouter model (poolside laguna 2.1 fast responder, tested and verified)
const String _freeModel = 'poolside/laguna-s-2.1:free';

// ─── Arabic Typography Helper (Uses Tajawal for Arabic) ───────────────────────
bool _isArabicText(String text) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}

TextStyle _aiTextStyle(
  BuildContext context, {
  required String text,
  double fontSize = 14.5,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
  double? letterSpacing,
  FontStyle? fontStyle,
  TextDecoration? decoration,
  Color? decorationColor,
}) {
  final hasArabic = _isArabicText(text) || Directionality.of(context) == TextDirection.rtl;
  if (hasArabic) {
    return GoogleFonts.tajawal(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.5,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height ?? 1.5,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    decoration: decoration,
    decorationColor: decorationColor,
  );
}


// ─── Data Models ──────────────────────────────────────────────────────────────
class _ConversationMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;

  const _ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _ConversationMessage.fromJson(Map<String, dynamic> json) =>
      _ConversationMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class _Conversation {
  final String id;
  String title;
  List<_ConversationMessage> messages;
  DateTime updatedAt;

  _Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory _Conversation.fromJson(Map<String, dynamic> json) => _Conversation(
        id: json['id'] as String,
        title: json['title'] as String,
        messages: (json['messages'] as List)
            .map((m) => _ConversationMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class _ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? attachedFileName;

  const _ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachedFileName,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen>
    with SingleTickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  bool _isTyping = false;
  bool _isLoadingData = false;

  // Attach modal
  bool _showAttachModal = false;
  String? _pendingFileText;   // extracted text from file
  String? _pendingFileName;   // original file name
  XFile? _pendingImage;       // image for display only

  // History panel
  bool _showHistory = false;
  List<_Conversation> _conversations = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _currentConversationId;

  // Typing animation
  late AnimationController _typingAnimCtrl;
  late Animation<double> _typingAnim;

  // Cached snapshot
  StudentAISnapshot? _cachedSnapshot;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    _typingAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _typingAnim = CurvedAnimation(parent: _typingAnimCtrl, curve: Curves.easeInOut);
    _typingAnimCtrl.repeat(reverse: true);

    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus) {
        _scrollToBottom();
      }
    });

    _loadConversations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navBarHiddenProvider.notifier).state = true;
      _initAI();
    });
  }

  Future<void> _initAI() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      // Pre-fetch snapshot in background (will be ready when first message sent)
      final snapshot = await ref.read(studentAISnapshotProvider.future);
      _cachedSnapshot = snapshot;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isLoadingData = false;
    });
    _addWelcome();
  }

  // ─── Conversation Persistence ───────────────────────────────────────────────
  Future<void> _loadConversations() async {
    final dir = await getConversationDir();
    final files = dir.listSync().whereType<File>().toList();
    final convs = <_Conversation>[];
    for (final f in files) {
      try {
        final data = jsonDecode(await f.readAsString());
        convs.add(_Conversation.fromJson(data as Map<String, dynamic>));
      } catch (_) {}
    }
    convs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (mounted) setState(() => _conversations = convs);
  }

  Future<void> _saveCurrentConversation() async {
    if (_messages.isEmpty) return;
    final convId = _currentConversationId ??
        DateTime.now().millisecondsSinceEpoch.toString();
    _currentConversationId ??= convId;
    final firstUser = _messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => _messages.first,
    );
    final title = firstUser.content.length > 45
        ? '${firstUser.content.substring(0, 45)}...'
        : firstUser.content;
    final conv = _Conversation(
      id: convId,
      title: title,
      messages: _messages
          .map((m) => _ConversationMessage(
                id: m.id,
                role: m.role,
                content: m.content,
                timestamp: m.timestamp,
              ))
          .toList(),
      updatedAt: DateTime.now(),
    );
    final dir = await getConversationDir();
    await File('${dir.path}/$convId.json').writeAsString(jsonEncode(conv.toJson()));
    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx >= 0) {
      _conversations[idx] = conv;
    } else {
      _conversations.insert(0, conv);
    }
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (mounted) setState(() {});
  }

  Future<void> _deleteConversation(String id) async {
    final conv = _conversations.firstWhere((c) => c.id == id);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _DeleteDialog(title: conv.title),
    );
    if (confirmed != true) return;
    try {
      final dir = await getConversationDir();
      final file = File('${dir.path}/$id.json');
      if (file.existsSync()) await file.delete();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _conversations.removeWhere((c) => c.id == id);
        if (_currentConversationId == id) {
          _currentConversationId = null;
          _startNewChat();
        }
      });
    }
  }

  void _loadConversation(_Conversation conv) {
    setState(() {
      _messages.clear();
      for (final m in conv.messages) {
        _messages.add(_ChatMessage(
          id: m.id,
          role: m.role,
          content: m.content,
          timestamp: m.timestamp,
        ));
      }
      _currentConversationId = conv.id;
      _showHistory = false;
    });
    _scrollToBottom();
  }

  void _addWelcome() {
    if (_messages.isNotEmpty) return;
    final name = _cachedSnapshot?.studentContext?.fullName?.split(' ').first ?? '';
    final greeting = _buildWelcomeMessage(name);
    setState(() {
      _messages.add(_ChatMessage(
        id: 'welcome',
        role: 'assistant',
        content: greeting,
        timestamp: DateTime.now(),
      ));
    });
  }

  String _buildWelcomeMessage(String firstName) {
    final lang = Localizations.localeOf(context).languageCode;
    final name = firstName.isNotEmpty ? ' $firstName' : '';
    if (lang == 'ar') {
      return 'مرحباً$name ! 👋\nكيف يمكنني مساعدتك اليوم؟';
    } else if (lang == 'fr') {
      return 'Bonjour$name ! 👋\nComment puis-je t\'aider aujourd\'hui ?';
    } else {
      return 'Hello$name! 👋\nHow can I help you today?';
    }
  }

  // ─── Messaging ──────────────────────────────────────────────────────────────
  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingFileText == null && _pendingImage == null) return;

    final fileName = _pendingFileName;
    final fileText = _pendingFileText;

    String displayContent = trimmed;
    if (fileName != null) {
      displayContent = trimmed.isEmpty
          ? '📎 $fileName'
          : '$trimmed\n\n📎 $fileName';
    }

    final ts = DateTime.now();
    setState(() {
      _messages.add(_ChatMessage(
        id: ts.millisecondsSinceEpoch.toString(),
        role: 'user',
        content: displayContent,
        timestamp: ts,
        attachedFileName: fileName,
      ));
      _isTyping = true;
      _inputController.clear();
      _pendingFileText = null;
      _pendingFileName = null;
      _pendingImage = null;
    });
    _scrollToBottom();
    _callOpenRouter(userDisplayContent: displayContent, fileText: fileText);
  }

  Future<void> _callOpenRouter({
    required String userDisplayContent,
    String? fileText,
  }) async {
    // Dynamically detect user's input language (supports mid-conversation language switching)
    String effectiveLang = Localizations.localeOf(context).languageCode;
    final cleanQuery = userDisplayContent.trim().toLowerCase();
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(userDisplayContent)) {
      effectiveLang = 'ar';
    } else if (RegExp(r'\b(list|all|my|material|results|what|is|the|schedule|balance|grades|how|when|where|who|why|grade|result)\b')
        .hasMatch(cleanQuery)) {
      effectiveLang = 'en';
    } else if (RegExp(r'\b(donne|affiche|mes|mon|ma|notes|cours|quel|quelle|quels|quelles|combien|solde|bonjour|salut)\b')
        .hasMatch(cleanQuery)) {
      effectiveLang = 'fr';
    }

    try {
      // Always ensure snapshot is fresh from database
      try {
        _cachedSnapshot = await ref.refresh(studentAISnapshotProvider.future);
      } catch (_) {
        _cachedSnapshot ??= await ref.read(studentAISnapshotProvider.future);
      }
      final snapshot = _cachedSnapshot!;

      final systemPrompt = buildSystemPrompt(
        snapshot: snapshot,
        languageCode: effectiveLang,
      );

      // Build history excluding welcome message
      final history = _messages
          .where((m) => m.id != 'welcome')
          .map((m) => formatMessageForAPI(
                role: m.role,
                content: m.content,
                fileText: m.id == _messages.last.id ? fileText : null,
              ))
          .toList();

      final reply = await callOpenRouter(
        apiKey: _openRouterApiKey,
        systemPrompt: systemPrompt,
        history: history,
        model: _freeModel,
        snapshot: snapshot,
        userQuery: userDisplayContent,
        languageCode: effectiveLang,
      );

      if (!mounted) return;
      final ts = DateTime.now();
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          id: ts.millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: reply,
          timestamp: ts,
        ));
      });
      _scrollToBottom();
      _saveCurrentConversation();
    } catch (e, st) {
      debugPrint('Error calling AI service: $e\n$st');
      if (!mounted) return;
      final errorMessage = effectiveLang == 'ar'
          ? '⚠️ تعذر الاتصال بالمساعد الذكي حالياً. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.'
          : (effectiveLang == 'fr'
              ? '⚠️ Impossible de joindre l\'assistant IA pour le moment. Vérifie ta connexion internet et réessaie.'
              : '⚠️ Unable to connect to the AI assistant right now. Please check your internet connection and try again.');

      final ts = DateTime.now();
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          id: ts.millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: errorMessage,
          timestamp: ts,
        ));
      });
      _scrollToBottom();
      _saveCurrentConversation();
    }
  }



  void _scrollToBottom({int delayMs = 100}) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ─── File Attachment ─────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() => _showAttachModal = false);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        final (name, text) = await FileTextExtractor.extract(file);
        setState(() {
          _pendingFileName = name;
          _pendingFileText = text;
          _pendingImage = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _showAttachModal = false);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null && mounted) {
        // Convert image to text description for the AI
        setState(() {
          _pendingImage = image;
          _pendingFileName = image.name;
          _pendingFileText =
              '[Image attached: ${image.name}] — The student has attached an image. Please ask them to describe it if you need to analyze its content, as image vision is not available in this mode.';
        });
      }
    } catch (_) {}
  }

  void _clearAttachment() {
    setState(() {
      _pendingFileText = null;
      _pendingFileName = null;
      _pendingImage = null;
    });
  }

  // ─── Quick Prompts ───────────────────────────────────────────────────────────
  List<String> _getQuickPrompts() {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'ar') {
      return [
        '📊 ما هو معدلي العام؟',
        '📅 ما هو جدولي غداً؟',
        '⚠️ كم غياباً لديّ؟',
        '💰 ما وضعي المالي؟',
        '📢 ما آخر الإشعارات؟',
        '📚 أفضل مادة عندي؟',
      ];
    } else if (lang == 'fr') {
      return [
        '📊 Quelle est ma moyenne générale?',
        '📅 Quel est mon emploi du temps demain?',
        '⚠️ Combien d\'absences ai-je?',
        '💰 Quel est mon solde?',
        '📢 Quelles sont les dernières notifs?',
        '📚 Quelle est ma meilleure matière?',
      ];
    } else {
      return [
        '📊 What\'s my overall average?',
        '📅 What\'s my schedule tomorrow?',
        '⚠️ How many absences do I have?',
        '💰 What\'s my payment status?',
        '📢 What are the latest notifications?',
        '📚 Which subject am I best at?',
      ];
    }
  }

  void _startNewChat() {
    _currentConversationId = null;
    _searchQuery = '';
    _searchController.clear();
    setState(() {
      _messages.clear();
      _addWelcome();
    });
  }

  @override
  void dispose() {
    ref.read(navBarHiddenProvider.notifier).state = false;
    _inputController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _typingAnimCtrl.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (bottomInset > _lastBottomInset) {
      // Keyboard opened: automatically elevate content and scroll up like Messenger/DMs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(delayMs: 80);
        _scrollToBottom(delayMs: 260);
      });
    }
    _lastBottomInset = bottomInset;

    // Show quick prompts only when there's only the welcome message
    final showQuickPrompts = _messages.length == 1 &&
        _messages.first.role == 'assistant' &&
        !_isTyping;

    return PopScope(
      canPop: !_showHistory,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showHistory) {
          setState(() => _showHistory = false);
          return;
        }
        if (didPop) {
          ref.read(navBarHiddenProvider.notifier).state = false;
        }
      },
      child: Stack(
        children: [
          // Main Chat Area (blurred when history open)
          ImageFiltered(
            enabled: _showHistory,
            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF8F0FC),
                      Color(0xFFF0E6F8),
                      Color(0xFFEAF0FA),
                      Color(0xFFF4F8FC),
                      Color(0xFFFAFCFD),
                    ],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: bottomInset == 0,
                  child: Column(
                    children: [
                      // Top Bar with safe spacing
                      Padding(
                        padding: EdgeInsets.only(
                          top: topPadding + 8,
                          left: 16,
                          right: 16,
                          bottom: 6,
                        ),
                        child: _buildTopBar(),
                      ),

                      // Messages List - Takes all available space above input bar
                      Expanded(
                        child: ClipRect(
                          child: ScrollConfiguration(
                            behavior: const ScrollBehavior().copyWith(
                              overscroll: false,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () => FocusScope.of(context).unfocus(),
                              behavior: HitTestBehavior.translucent,
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: _messages.length +
                                    (_isTyping ? 1 : 0) +
                                    (showQuickPrompts ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (showQuickPrompts && index == 1) {
                                    return _buildQuickPrompts();
                                  }
                                  final msgIdx = showQuickPrompts && index > 1
                                      ? index - 1
                                      : index;
                                  if (msgIdx == _messages.length && _isTyping) {
                                    return _TypingIndicator(listenable: _typingAnim);
                                  }
                                  if (msgIdx < _messages.length) {
                                    return _MessageBubble(message: _messages[msgIdx]);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Attachment preview
                      if (_pendingFileName != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: _buildAttachmentPreview(),
                        ),

                      // Bottom Input Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                        child: Center(
                          child: Container(
                            constraints:
                                const BoxConstraints(maxWidth: 600),
                            child: _buildInputBar(isRtl),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // History sidebar overlay
          IgnorePointer(
            ignoring: !_showHistory,
            child: AnimatedOpacity(
              opacity: _showHistory ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: () => setState(() => _showHistory = false),
                child: Container(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
          ),
          AnimatedPositioned(
            left: isRtl ? (_showHistory ? 0 : -screenWidth * 0.82) : null,
            right: isRtl ? null : (_showHistory ? 0 : -screenWidth * 0.82),
            top: 0,
            bottom: 0,
            width: screenWidth * 0.82,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (isRtl) {
                  if ((details.primaryDelta ?? 0) < -8) setState(() => _showHistory = false);
                } else {
                  if ((details.primaryDelta ?? 0) > 8) setState(() => _showHistory = false);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isRtl ? 0 : 28),
                  bottomLeft: Radius.circular(isRtl ? 0 : 28),
                  topRight: Radius.circular(isRtl ? 28 : 0),
                  bottomRight: Radius.circular(isRtl ? 28 : 0),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      border: Border(
                        left: isRtl
                            ? BorderSide.none
                            : BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                        right: isRtl
                            ? BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: SafeArea(
                      child: Material(
                        type: MaterialType.transparency,
                        child: _buildHistoryPanel(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Attach modal
          if (_showAttachModal) _buildAttachModal(context),
        ],
      ),
    );
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(44),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7A8698).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(44),
            ),
            child: Row(
              children: [
                // Back
                GestureDetector(
                  onTap: () {
                    ref.read(navBarHiddenProvider.notifier).state = false;
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      color: const Color(0xFF475569),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // NOVA avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_pink, _pinkLight],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOVA',
                        style: ArabicTypography.headerStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLoadingData
                                  ? Colors.orange
                                  : _isTyping
                                      ? Colors.blue
                                      : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isTyping
                                ? l10n.translate('ai_thinking')
                                : _isLoadingData
                                    ? l10n.loading
                                    : l10n.translate('ai_assistant_role'),
                            style: ArabicTypography.bodyStyle(
                              context,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _pink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Refresh data button
                GestureDetector(
                  onTap: _isLoadingData
                      ? null
                      : () async {
                          setState(() => _isLoadingData = true);
                          try {
                            _cachedSnapshot =
                                await ref.refresh(studentAISnapshotProvider.future);
                          } catch (_) {}
                          if (mounted) setState(() => _isLoadingData = false);
                        },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                    ),
                    child: _isLoadingData
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: IosLoader.small(size: 16, color: _pink),
                          )
                        : const Icon(Icons.refresh_rounded,
                            color: Color(0xFF64748B), size: 18),
                  ),
                ),
                const SizedBox(width: 6),
                // History
                GestureDetector(
                  onTap: () {
                    setState(() => _showHistory = true);
                    _loadConversations();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                    ),
                    child: const Icon(Icons.menu_rounded,
                        color: Color(0xFF64748B), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPrompts() {
    final prompts = _getQuickPrompts();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: prompts
            .map(
              (p) => GestureDetector(
                onTap: () {
                  _inputController.text = p;
                  _sendMessage(p);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF64748B).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    p,
                    style: _aiTextStyle(
                      context,
                      text: p,
                      fontSize: 13,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pink.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _pink.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Preview thumbnail or icon
          if (_pendingImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_pendingImage!.path),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fileIcon(),
              ),
            )
          else
            _fileIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingFileName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArabicTypography.bodyStyle(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '✅ Ready to send',
                  style: ArabicTypography.bodyStyle(
                    context,
                    fontSize: 11,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _clearAttachment,
            child: const Icon(Icons.close_rounded,
                size: 20, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _fileIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _pink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.insert_drive_file_rounded, color: _pink, size: 22),
    );
  }

  Widget _buildInputBar(bool isRtl) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7A8698).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                // Attach button
                GestureDetector(
                  onTap: () => setState(() => _showAttachModal = true),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF1F5F9),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, size: 22, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 4),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    textInputAction: TextInputAction.send,
                    maxLines: 4,
                    minLines: 1,
                    style: _aiTextStyle(
                      context,
                      text: _inputController.text.isNotEmpty
                          ? _inputController.text
                          : (isRtl ? 'ع' : ''),
                      fontSize: 15,
                      color: const Color(0xFF475569),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      hintText: AppLocalizations.of(context)
                          .translate('ask_ai_question_hint'),
                      hintStyle: _aiTextStyle(
                        context,
                        text: AppLocalizations.of(context)
                            .translate('ask_ai_question_hint'),
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      isDense: true,
                    ),
                    onSubmitted: (val) => _sendMessage(val),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Send button
                GestureDetector(
                  onTap: (_inputController.text.trim().isNotEmpty ||
                              _pendingFileText != null) &&
                          !_isTyping
                      ? () => _sendMessage(_inputController.text)
                      : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_inputController.text.trim().isNotEmpty ||
                                  _pendingFileText != null) &&
                              !_isTyping
                          ? _pink
                          : const Color(0xFFCBD5E1),
                      boxShadow: (_inputController.text.trim().isNotEmpty ||
                                  _pendingFileText != null) &&
                              !_isTyping
                          ? [
                              BoxShadow(
                                color: _pink.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: _isTyping
                        ? const IosLoader.small(size: 18, color: Colors.white)
                        : Transform.scale(
                            scaleX: isRtl ? -1 : 1,
                            child: const Icon(Icons.send, size: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachModal(BuildContext ctx) {
    final l10n = AppLocalizations.of(ctx);
    return GestureDetector(
      onTap: () => setState(() => _showAttachModal = false),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: GestureDetector(
              onTap: () {},
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(start: 20),
                                  child: Text(
                                    l10n.translate('attach_title'),
                                    style: ArabicTypography.headerStyle(
                                      ctx,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _showAttachModal = false),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    margin: const EdgeInsetsDirectional.only(end: 12),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        size: 20, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _AttachOption(
                              icon: Icons.insert_drive_file_outlined,
                              iconColor: Colors.white,
                              bgColor: const Color(0xFF6366F1),
                              title: 'Document / PDF',
                              subtitle: 'PDF, DOCX, TXT, CSV...',
                              onTap: _pickFile,
                            ),
                            _AttachOption(
                              icon: Icons.image_outlined,
                              iconColor: Colors.white,
                              bgColor: _pink,
                              title: l10n.translate('photo_library'),
                              subtitle: l10n.translate('photo_library_desc'),
                              onTap: () => _pickImage(ImageSource.gallery),
                            ),
                            _AttachOption(
                              icon: Icons.camera_alt_outlined,
                              iconColor: Colors.white,
                              bgColor: _pink,
                              title: l10n.translate('take_photo'),
                              subtitle: l10n.translate('take_photo_desc'),
                              onTap: () => _pickImage(ImageSource.camera),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── History Panel ────────────────────────────────────────────────────────────
  Widget _buildHistoryPanel() {
    final l10n = AppLocalizations.of(context);
    final filtered = _searchQuery.isEmpty
        ? _conversations
        : _conversations
            .where(
              (c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    return Material(
      type: MaterialType.transparency,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search + Close
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      hintStyle: ArabicTypography.bodyStyle(
                        context,
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF94A3B8), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              child: const Icon(Icons.close_rounded,
                                  color: Color(0xFF94A3B8), size: 18),
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    cursorColor: const Color(0xFF374151),
                    style: ArabicTypography.bodyStyle(
                      context,
                      fontSize: 14,
                      color: const Color(0xFF374151),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _showHistory = false),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Color(0xFF374151), size: 20),
                ),
              ),
            ],
          ),
        ),

        // Section title
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 6),
          child: Text(
            l10n.translate('chat_history'),
            style: ArabicTypography.headerStyle(
              context,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
        ),

        // Conversation list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F7FB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF94A3B8), size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? l10n.translate('no_conversations')
                            : l10n.noResults,
                        style: ArabicTypography.bodyStyle(
                          context,
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final conv = filtered[index];
                    final isCurrent = conv.id == _currentConversationId;
                    return _buildConversationTile(conv, isCurrent);
                  },
                ),
        ),

        // New conversation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: GestureDetector(
            onTap: () {
              setState(() => _showHistory = false);
              _startNewChat();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.translate('new_conversation'),
                    style: ArabicTypography.buttonStyle(
                      context,
                      color: Colors.grey[700]!,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildConversationTile(_Conversation conv, bool isCurrent) {
    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
      ),
      onDismissed: (_) => _deleteConversation(conv.id),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          onTap: () => _loadConversation(conv),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCurrent
                  ? _pink.withValues(alpha: 0.12)
                  : const Color(0xFFF5F7FB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCurrent
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              color: isCurrent ? _pink : const Color(0xFF374151),
              size: 20,
            ),
          ),
          title: Text(
            conv.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ArabicTypography.headerStyle(
              context,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isCurrent ? _pink : const Color(0xFF374151),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _formatDate(conv.updatedAt),
              style: ArabicTypography.bodyStyle(
                context,
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _deleteConversation(conv.id),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 18, color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Delete Dialog ─────────────────────────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final String title;
  const _DeleteDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.translate('delete_conversation'),
                  textAlign: TextAlign.center,
                  style: ArabicTypography.headerStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${title.length > 30 ? '${title.substring(0, 30)}...' : title}"',
                  textAlign: TextAlign.center,
                  style: ArabicTypography.bodyStyle(
                    context,
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              l10n.cancel,
                              style: ArabicTypography.buttonStyle(
                                context,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              l10n.delete,
                              style: ArabicTypography.buttonStyle(
                                context,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Message Bubble with Markdown Rendering ────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // NOVA avatar
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_pink, _pinkLight],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.84,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? _pink : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? (isRtl ? 4 : 20) : (isRtl ? 20 : 5)),
                  bottomRight: Radius.circular(isUser ? (isRtl ? 20 : 4) : (isRtl ? 5 : 20)),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFFE8ECF1)),
                boxShadow: isUser
                    ? [
                        BoxShadow(
                          color: _pink.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        const BoxShadow(
                          color: Color(0x1A64748B),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: isUser
                  ? _buildUserContent(context, isRtl)
                  : _buildAssistantContent(context),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildUserContent(BuildContext context, bool isRtl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.attachedFileName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.attach_file, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    message.attachedFileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ArabicTypography.bodyStyle(
                      context,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.content.isNotEmpty &&
              message.content != '📎 ${message.attachedFileName}')
            const SizedBox(height: 8),
        ],
        if (message.content.isNotEmpty &&
            !(message.content == '📎 ${message.attachedFileName}'))
          Text(
            message.content.replaceFirst('📎 ${message.attachedFileName}\n\n', '').trim(),
            style: _aiTextStyle(
              context,
              text: message.content,
              fontSize: 14.5,
              color: Colors.white,
              height: 1.5,
            ),
          ),
      ],
    );
  }

  Widget _buildAssistantContent(BuildContext context) {
    final isWelcome = message.id == 'welcome';
    final actions = isWelcome ? <_RouteAction>[] : _detectRouteActions(message.content, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MarkdownText(
          text: message.content,
          textColor: const Color(0xFF334155),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.take(3).map((act) {
              return GestureDetector(
                onTap: () => context.push(act.route),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _pink.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(act.icon, size: 14, color: _pink),
                      const SizedBox(width: 6),
                      Text(
                        act.label,
                        style: ArabicTypography.bodyStyle(
                          context,
                          fontSize: 12,
                          color: _pink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _pink),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _RouteAction {
  final String route;
  final String label;
  final IconData icon;

  const _RouteAction({
    required this.route,
    required this.label,
    required this.icon,
  });
}

List<_RouteAction> _detectRouteActions(String content, BuildContext context) {
  final actions = <_RouteAction>[];
  final lower = content.toLowerCase();
  final lang = Localizations.localeOf(context).languageCode;

  void check({
    required List<String> keywords,
    required String route,
    required String labelAr,
    required String labelFr,
    required String labelEn,
    required IconData icon,
  }) {
    if (keywords.any((kw) => lower.contains(kw))) {
      final label = switch (lang) {
        'ar' => labelAr,
        'fr' => labelFr,
        _ => labelEn,
      };
      if (!actions.any((a) => a.route == route)) {
        actions.add(_RouteAction(route: route, label: label, icon: icon));
      }
    }
  }

  check(
    keywords: ['/emploi', 'emploi du temps', 'جدول الأوقات', 'timetable', 'حصص'],
    route: '/emploi',
    labelAr: 'فتح جدول الأوقات',
    labelFr: 'Emploi du temps',
    labelEn: 'Open Timetable',
    icon: Icons.calendar_today_rounded,
  );
  check(
    keywords: ['/resultats', 'résultat', 'résultats', 'النتائج', 'معدل', 'درجات', 'grades', 'bulletin'],
    route: '/resultats',
    labelAr: 'عرض النتائج والمعدلات',
    labelFr: 'Voir les Résultats',
    labelEn: 'View Results',
    icon: Icons.school_rounded,
  );
  check(
    keywords: ['/absences', 'absence', 'absences', 'غياب', 'غيابات', 'attendance'],
    route: '/absences',
    labelAr: 'سجل الغيابات',
    labelFr: 'Consulter Absences',
    labelEn: 'Check Absences',
    icon: Icons.event_busy_rounded,
  );
  check(
    keywords: ['/mon-solde', 'solde', 'paiement', 'frais', 'الرصيد', 'دفع', 'مصاريف', 'payments', 'balance'],
    route: '/mon-solde',
    labelAr: 'الرصيد والمصاريف',
    labelFr: 'Mon Solde',
    labelEn: 'My Balance',
    icon: Icons.account_balance_wallet_rounded,
  );
  check(
    keywords: ['/documents', 'document', 'documents', 'شهادة', 'مستند', 'وثائق', 'attestation', 'certificat'],
    route: '/documents',
    labelAr: 'المستندات والشهادات',
    labelFr: 'Mes Documents',
    labelEn: 'My Documents',
    icon: Icons.folder_open_rounded,
  );
  check(
    keywords: ['/courses', 'cours', 'دروس', 'مقررات', 'course', 'courses'],
    route: '/courses',
    labelAr: 'المقررات والدروس',
    labelFr: 'Mes Cours',
    labelEn: 'My Courses',
    icon: Icons.menu_book_rounded,
  );
  check(
    keywords: ['/messages', 'message', 'messages', 'رسائل', 'رسالة'],
    route: '/messages',
    labelAr: 'رسائل الفصل',
    labelFr: 'Messages de classe',
    labelEn: 'Class Messages',
    icon: Icons.mail_rounded,
  );
  check(
    keywords: ['/notifications', 'notification', 'notifications', 'إشعار', 'إعلانات', 'announcement'],
    route: '/notifications',
    labelAr: 'الإعلانات والإشعارات',
    labelFr: 'Notifications',
    labelEn: 'Notifications',
    icon: Icons.notifications_rounded,
  );
  check(
    keywords: ['/suggestions', 'suggestion', 'suggestions', 'مقترح', 'شكوى', 'reclamation'],
    route: '/suggestions',
    labelAr: 'صندوق المقترحات',
    labelFr: 'Boîte à suggestions',
    labelEn: 'Suggestions',
    icon: Icons.lightbulb_rounded,
  );
  check(
    keywords: ['/stats', 'statistique', 'statistiques', 'إحصائيات', 'statistics'],
    route: '/stats',
    labelAr: 'الإحصائيات والرسوم',
    labelFr: 'Statistiques',
    labelEn: 'Statistics',
    icon: Icons.bar_chart_rounded,
  );
  check(
    keywords: ['/profile', 'profil', 'profile', 'الملف الشخصي', 'حسابي'],
    route: '/profile',
    labelAr: 'الملف الشخصي',
    labelFr: 'Mon Profil',
    labelEn: 'My Profile',
    icon: Icons.person_rounded,
  );

  return actions;
}

// ─── Markdown Text Renderer ───────────────────────────────────────────────────
/// Renders a subset of markdown: headers, bold, italic, bullets, numbered lists,
/// blockquotes, horizontal rules, and emojis — all native Flutter Text widgets.
class _MarkdownText extends StatelessWidget {
  final String text;
  final Color textColor;

  const _MarkdownText({required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final rawLines = text.split('\n');
    final lines = <String>[];
    for (final raw in rawLines) {
      final t = raw.trim();
      // Skip empty blockquotes like '>' or '>>>'
      if (t == '>' || t == '>>>') continue;
      lines.add(raw);
    }

    final widgets = <Widget>[];
    bool lastWasEmpty = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Empty line → collapse consecutive empty lines into a single controlled gap
      if (trimmed.isEmpty) {
        if (!lastWasEmpty && widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
          lastWasEmpty = true;
        }
        continue;
      }
      lastWasEmpty = false;

      // Horizontal rule
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: textColor.withValues(alpha: 0.15), thickness: 1),
        ));
        continue;
      }

      // Headings (#, ##, ###, ####, #####, ######)
      final headerMatch = RegExp(r'^(#{1,6})\s*(.+)$').firstMatch(trimmed);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!.trim();
        double fontSize;
        FontWeight weight = FontWeight.w800;
        double topPadding;
        double bottomPadding = 4;
        Color headerColor = const Color(0xFF0F172A);

        switch (level) {
          case 1:
            fontSize = 19;
            topPadding = i == 0 ? 0 : 14;
            break;
          case 2:
            fontSize = 17;
            topPadding = i == 0 ? 0 : 12;
            break;
          case 3:
            fontSize = 15.5;
            topPadding = i == 0 ? 0 : 10;
            break;
          case 4:
            fontSize = 14.5;
            weight = FontWeight.w700;
            topPadding = i == 0 ? 0 : 8;
            headerColor = const Color(0xFF1E293B);
            break;
          default:
            fontSize = 13.5;
            weight = FontWeight.w700;
            topPadding = i == 0 ? 0 : 6;
            headerColor = const Color(0xFF334155);
        }

        widgets.add(Padding(
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          child: RichText(
            text: _parseInline(
              content,
              context,
              _aiTextStyle(
                context,
                text: content,
                fontSize: fontSize,
                fontWeight: weight,
                color: headerColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ));
        continue;
      }

      // Standalone Bold Section / Subject Title (e.g. "**📊 General Results**" or "**📐 Mathématiques** (Coeff 3.0) — **14.25/20**")
      final isStandaloneBoldTitle = (trimmed.startsWith('**') && trimmed.endsWith('**') && trimmed.length > 4) ||
          RegExp(r'^([\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]\s*)?\*\*(.+?)\*\*[:\s]*$', unicode: true).hasMatch(trimmed) ||
          RegExp(r'^([\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]\s*)?\*\*(.+?)\*\*\s*(`.+?`)?\s*([—–-]\s*\*\*.+?\*\*)?$', unicode: true).hasMatch(trimmed);

      if (isStandaloneBoldTitle) {
        final rawTitle = trimmed.replaceAll('**', '').replaceAll('`', '');
        widgets.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10, bottom: 4),
          child: RichText(
            text: _parseInline(
              trimmed,
              context,
              _aiTextStyle(
                context,
                text: rawTitle,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ));
        continue;
      }

      // Blockquote (>)
      if (trimmed.startsWith('> ') || (trimmed.startsWith('>') && trimmed.length > 1)) {
        final content = trimmed.replaceFirst(RegExp(r'^>\s*'), '');
        if (content.isEmpty) continue;
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
          decoration: BoxDecoration(
            color: _pink.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: const BorderDirectional(
              start: BorderSide(color: _pink, width: 3),
            ),
          ),
          child: RichText(
            text: _parseInline(
              content,
              context,
              _aiTextStyle(
                context,
                text: content,
                fontSize: 13.5,
                color: textColor,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ),
        ));
        continue;
      }

      // Bullet list (- , * , • , •) with indentation support for sub-items
      final isIndented = line.startsWith('  ') || line.startsWith('\t');
      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('• ') ||
          trimmed.startsWith('•')) {
        final content = trimmed.replaceFirst(RegExp(r'^([-*•]\s*|\u2022\s*)'), '');

        // Check if this is an empty heading bullet like "Strong Performers:" without content
        final isCategoryHeadingOnly = content.endsWith(':') && !content.contains('(') && !content.contains('/');
        if (isCategoryHeadingOnly) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: RichText(
              text: _parseInline(
                content,
                context,
                _aiTextStyle(
                  context,
                  text: content,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ));
          continue;
        }

        widgets.add(Padding(
          padding: EdgeInsetsDirectional.only(
            start: isIndented ? 18 : 2,
            bottom: isIndented ? 2.5 : 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: isIndented ? 2 : 2,
                  top: isIndented ? 6.5 : 7,
                  end: isIndented ? 6 : 8,
                ),
                child: Container(
                  width: isIndented ? 4.0 : 5.5,
                  height: isIndented ? 4.0 : 5.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isIndented
                        ? _pink.withValues(alpha: 0.45)
                        : _pink.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: _parseInline(
                    content,
                    context,
                    _aiTextStyle(
                      context,
                      text: content,
                      fontSize: isIndented ? 13 : 14,
                      color: isIndented ? const Color(0xFF475569) : textColor,
                      height: isIndented ? 1.4 : 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // Numbered list (1. 2. etc.)
      final numberedMatch =
          RegExp(r'^(\d+)\.\s(.+)$').firstMatch(trimmed);
      if (numberedMatch != null) {
        final num = numberedMatch.group(1)!;
        final content = numberedMatch.group(2)!;
        widgets.add(Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsetsDirectional.only(end: 8, top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pink.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  num,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _pink,
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: _parseInline(
                    content,
                    context,
                    _aiTextStyle(
                      context,
                      text: content,
                      fontSize: 14,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // Regular paragraph
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: RichText(
          text: _parseInline(
            trimmed,
            context,
            _aiTextStyle(
              context,
              text: trimmed,
              fontSize: 14.5,
              color: textColor,
              height: 1.55,
            ),
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parse inline markdown: **bold**, *italic*, `code`, [title](url)
  TextSpan _parseInline(String text, BuildContext context, TextStyle base) {
    final spans = <InlineSpan>[];
    // Pattern: [title](url), **bold**, *italic*, `code`
    final pattern = RegExp(r'\[(.+?)\]\((.+?)\)|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        final chunk = text.substring(lastEnd, match.start);
        spans.add(TextSpan(
          text: chunk,
          style: _isArabicText(chunk)
              ? GoogleFonts.tajawal(
                  fontSize: base.fontSize,
                  fontWeight: base.fontWeight,
                  color: base.color,
                  height: base.height,
                  fontStyle: base.fontStyle,
                )
              : base,
        ));
      }
      if (match.group(1) != null && match.group(2) != null) {
        // [title](url)
        final linkTitle = match.group(1)!;
        final linkTarget = match.group(2)!;
        spans.add(TextSpan(
          text: linkTitle,
          style: _isArabicText(linkTitle)
              ? GoogleFonts.tajawal(
                  fontSize: base.fontSize,
                  color: _pink,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _pink.withValues(alpha: 0.5),
                )
              : base.copyWith(
                  color: _pink,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _pink.withValues(alpha: 0.5),
                ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (linkTarget.startsWith('/')) {
                context.push(linkTarget);
              }
            },
        ));
      } else if (match.group(3) != null) {
        // **bold**
        final boldContent = match.group(3)!;
        spans.add(TextSpan(
          text: boldContent,
          style: _isArabicText(boldContent)
              ? GoogleFonts.tajawal(
                  fontSize: base.fontSize,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: base.height,
                )
              : base.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ));
      } else if (match.group(4) != null) {
        // *italic*
        final italicContent = match.group(4)!;
        spans.add(TextSpan(
          text: italicContent,
          style: _isArabicText(italicContent)
              ? GoogleFonts.tajawal(
                  fontSize: base.fontSize,
                  fontStyle: FontStyle.italic,
                  color: base.color,
                  height: base.height,
                )
              : base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(5) != null) {
        // `code` / badge pill
        final codeText = match.group(5)!;
        spans.add(TextSpan(
          text: ' $codeText ',
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: const Color(0xFFFFF1F2),
            color: const Color(0xFFE11D48),
            fontWeight: FontWeight.w700,
            fontSize: (base.fontSize ?? 14) * 0.92,
          ),
        ));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      final chunk = text.substring(lastEnd);
      spans.add(TextSpan(
        text: chunk,
        style: _isArabicText(chunk)
            ? GoogleFonts.tajawal(
                fontSize: base.fontSize,
                fontWeight: base.fontWeight,
                color: base.color,
                height: base.height,
                fontStyle: base.fontStyle,
              )
            : base,
      ));
    }
    return TextSpan(children: spans);
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────
class _TypingIndicator extends AnimatedWidget {
  const _TypingIndicator({required super.listenable});

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final value = _animation.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_pink, _pinkLight]),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: const Color(0xFFE8ECF1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A64748B),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.33;
                final animVal = ((value - delay) % 1.0).clamp(0.0, 1.0);
                final bounce = animVal < 0.5 ? animVal * 2 : (1 - animVal) * 2;
                return Transform.translate(
                  offset: Offset(0, -bounce * 5),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pink.withValues(alpha: 0.4 + bounce * 0.6),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attach Option ────────────────────────────────────────────────────────────
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ArabicTypography.headerStyle(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: ArabicTypography.bodyStyle(
                        context,
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isRtl ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
                color: const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
