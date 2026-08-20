import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/ios_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const Color _pink = Color(0xFFFF2D78);
const String _openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');

class _Conversation {
  final String id;
  String title;
  List<_ConversationMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;

  _Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory _Conversation.fromJson(Map<String, dynamic> json) => _Conversation(
    id: json['id'] as String,
    title: json['title'] as String,
    messages: (json['messages'] as List)
        .map((m) => _ConversationMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

class _ConversationMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;

  _ConversationMessage({
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

  factory _ConversationMessage.fromJson(Map<String, dynamic> json) => _ConversationMessage(
    id: json['id'] as String,
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class _ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final XFile? pendingImage;

  const _ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.pendingImage,
  });
}

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
  bool _dataLoaded = false;
  XFile? _pendingImage;
  bool _showAttachModal = false;

  bool _showHistory = false;
  List<_Conversation> _conversations = [];
  String _searchQuery = '';
  String? _currentConversationId;

  late AnimationController _typingAnimCtrl;
  late Animation<double> _typingAnim;

  @override
  void initState() {
    super.initState();
    _typingAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _typingAnim = CurvedAnimation(
      parent: _typingAnimCtrl,
      curve: Curves.easeInOut,
    );
    _typingAnimCtrl.repeat(reverse: true);
    _loadConversations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _addWelcome());
  }

  Future<Directory> _getConvDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/conversations');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> _loadConversations() async {
    final dir = await _getConvDir();
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
    final convId = _currentConversationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _currentConversationId ??= convId;
    final firstUser = _messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => _messages.first,
    );
    final title = firstUser.content.length > 40
        ? '${firstUser.content.substring(0, 40)}...'
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final dir = await _getConvDir();
    final file = File('${dir.path}/$convId.json');
    await file.writeAsString(jsonEncode(conv.toJson()));
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
      builder: (ctx) => Dialog(
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
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
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
                  const Text(
                    'Supprimer la conversation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${conv.title.length > 30 ? '${conv.title.substring(0, 30)}...' : conv.title}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'Annuler',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Supprimer',
                                style: TextStyle(
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
      ),
    );
    if (confirmed == null || !confirmed) return;
    if (_currentConversationId == id) {
      _currentConversationId = null;
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
      _dataLoaded = true;
    });
    _scrollToBottom();
  }

  void _addWelcome() {
    setState(() {
      _dataLoaded = true;
      _messages.add(_ChatMessage(
        id: 'welcome',
        role: 'assistant',
        content: 'Bonjour, comment puis-je vous aider aujourd\'hui ?',
        timestamp: DateTime.now(),
      ));
    });
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingImage == null) return;
    final ts = DateTime.now();
    setState(() {
      _messages.add(_ChatMessage(
        id: ts.millisecondsSinceEpoch.toString(),
        role: 'user',
        content: trimmed,
        timestamp: ts,
        pendingImage: _pendingImage,
      ));
      _isTyping = true;
      _inputController.clear();
      _pendingImage = null;
    });
    _scrollToBottom();
    _callOpenRouter(trimmed);
  }

  Future<void> _callOpenRouter(String userMessage) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      );
      if (_openRouterApiKey.isEmpty) {
        throw StateError('Missing OPENROUTER_API_KEY configuration.');
      }
      request.headers.set(
        'Authorization',
        'Bearer $_openRouterApiKey',
      );
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('HTTP-Referer', 'https://studentportal.app');
      request.headers.set('X-Title', 'Student Portal');

      final history = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      request.write(jsonEncode({
        'model': 'openai/gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content':
                'You are NOVA, a helpful student assistant. Respond concisely in French. Be friendly and helpful.',
          },
          ...history,
        ],
        'temperature': 0.7,
        'max_tokens': 2048,
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(
          (data['error'] as Map<String, dynamic>)['message'] ?? 'API Error',
        );
      }

      final reply =
          (data['choices'] as List)[0]['message']['content'] as String;
      final ts = DateTime.now();
      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _mockRespond(userMessage);
    }
  }

  void _mockRespond(String userText) {
    String content;
    final lower = userText.toLowerCase();
    if (lower.contains('bonjour') ||
        lower.contains('salut') ||
        lower.contains('hello')) {
      content =
          'Bonjour ! Je suis NOVA, votre assistant étudiant. Comment puis-je vous aider ?';
    } else if (lower.contains('cours') || lower.contains('matière')) {
      content =
          'Vous trouverez vos cours dans la section "Cours" de l\'application.';
    } else if (lower.contains('note') || lower.contains('résultat')) {
      content =
          'Vos résultats sont dans la section "Résultats". Consultez vos notes par matière.';
    } else if (lower.contains('emploi') || lower.contains('horaire')) {
      content =
          'Votre emploi du temps est dans la section "Emploi du temps".';
    } else if (lower.contains('absence')) {
      content = 'Consultez vos absences dans la section "Absences".';
    } else if (lower.contains('aide') || lower.contains('peux')) {
      content =
          'Je peux vous aider avec vos cours, notes, emploi du temps, absences et documents.';
    } else if (lower.contains('merci')) {
      content = 'De rien ! N\'hésitez pas à me solliciter.';
    } else {
      content =
          'Je n\'ai pas bien compris. Je peux vous aider avec vos cours, notes, emploi du temps, absences ou documents.';
    }
    final ts = DateTime.now();
    setState(() {
      _messages.add(_ChatMessage(
        id: ts.millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: content,
        timestamp: ts,
      ));
    });
    _scrollToBottom();
    _saveCurrentConversation();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _pickImage(ImageSource source) {
    setState(() => _showAttachModal = false);
    ImagePicker()
        .pickImage(source: source, maxWidth: 1024, maxHeight: 1024)
        .then((image) {
      if (image != null && mounted) {
        setState(() => _pendingImage = image);
      }
    });
  }

  void _startNewChat() {
    _currentConversationId = null;
    setState(() {
      _messages.clear();
      _addWelcome();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _typingAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
        children: [
          Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8D5F2),
                    Color(0xFFD4C4E8),
                    Color(0xFFC9D6F0),
                    Color(0xFFE0EAF5),
                    Color(0xFFF0F5FA),
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: topPadding + 100,
                            bottom: bottomInset > 0 ? 140 : 220,
                          ),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isTyping) {
                              return _TypingIndicator(listenable: _typingAnim);
                            }
                            return _MessageBubble(
                              message: _messages[index],
                            );
                          },
                        ),
                        Positioned(
                          top: topPadding + 8,
                          left: 16,
                          right: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(44),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7A8698).withValues(alpha: 0.20),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(44),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(44),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
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
                                          child: const Icon(Icons.chevron_left,
                                              color: Color(0xFF475569), size: 22),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFFFF2D78),
                                              Color(0xFFFF5CA0)
                                            ],
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.auto_awesome,
                                            color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'NOVA',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            Text(
                                              _isTyping
                                                  ? 'Réfléchit...'
                                                  : _dataLoaded
                                                      ? 'Assistant Étudiant'
                                                      : 'Chargement...',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: _pink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => _showHistory = true);
                                          _loadConversations();
                                        },
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                                          ),
                                          child: const Icon(Icons.menu_rounded,
                                              color: Color(0xFF64748B), size: 22),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_pendingImage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset > 0 ? bottomInset + 80 : 210,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_pendingImage!.path),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 40,
                        height: 40,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Image attachée',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _pendingImage = null),
                    child: const Icon(Icons.close, size: 22, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset > 0 ? bottomInset + 8 : 140,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A8698).withValues(alpha: 0.20),
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
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocus,
                          textInputAction: TextInputAction.send,
                          maxLines: 4,
                          minLines: 1,
                          style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            hintText: 'Posez votre question...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10),
                            isDense: true,
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      GestureDetector(
                        onTap: (_inputController.text.trim().isNotEmpty || _pendingImage != null) && !_isTyping
                            ? () => _sendMessage(_inputController.text)
                            : null,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_inputController.text.trim().isNotEmpty || _pendingImage != null) && !_isTyping
                                ? _pink
                                : const Color(0xFFCBD5E1),
                            boxShadow: (_inputController.text.trim().isNotEmpty || _pendingImage != null) && !_isTyping
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
                              : const Icon(Icons.send, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showHistory)
            GestureDetector(
              onTap: () => setState(() => _showHistory = false),
              child: Container(
                  color: Colors.black.withValues(alpha: 0.4)),
            ),
          AnimatedPositioned(
            right: _showHistory ? 0 : -screenWidth * 0.78,
            top: 0,
            bottom: 0,
            width: screenWidth * 0.78,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    border: Border(
                      left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: _buildHistoryPanel(),
                ),
              ),
            ),
          ),
          if (_showAttachModal)
            GestureDetector(
              onTap: () =>
                  setState(() => _showAttachModal = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: GestureDetector(
                  onTap: () {},
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(28),
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
                                    const Padding(
                                      padding: EdgeInsets.only(left: 20),
                                      child: Text(
                                        'Joindre',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E293B),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _showAttachModal = false),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFF1F5F9),
                                        ),
                                        child: const Icon(Icons.close_rounded,
                                            size: 20, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _AttachOption(
                                  icon: Icons.image_outlined,
                                  iconColor: _pink,
                                  bgColor: const Color(0xFFFFF0F3),
                                  title: 'Bibliothèque photo',
                                  subtitle: 'Partager une image ou un document',
                                  onTap: () => _pickImage(ImageSource.gallery),
                                ),
                                _AttachOption(
                                  icon: Icons.camera_alt_outlined,
                                  iconColor: const Color(0xFFFF5CA0),
                                  bgColor: const Color(0xFFFFF0F3),
                                  title: 'Prendre une photo',
                                  subtitle: 'Capturer un document ou une note',
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
        ],
    );
  }

  Widget _buildHistoryPanel() {
    final filtered = _searchQuery.isEmpty
        ? _conversations
        : _conversations
            .where((c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _showHistory = false);
                  _startNewChat();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.note_add_rounded, color: Color(0xFF64748B), size: 22),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Text(
                'Historique',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune conversation',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildConversationTile(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildConversationTile(_Conversation conv) {
    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => _deleteConversation(conv.id),
      child: GestureDetector(
        onTap: () => _loadConversation(conv),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(conv.title),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(conv.updatedAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _deleteConversation(conv.id),
                child: const Icon(Icons.close, size: 16, color: Color(0xFFCBD5E1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text) {
    if (_searchQuery.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      );
    }
    final lower = text.toLowerCase();
    final query = _searchQuery.toLowerCase();
    final matches = <int>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(query, start);
      if (idx == -1) break;
      matches.add(idx);
      start = idx + query.length;
    }
    if (matches.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      );
    }
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final matchIdx in matches) {
      if (matchIdx > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, matchIdx),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(matchIdx, matchIdx + query.length),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _pink,
          backgroundColor: _pink.withValues(alpha: 0.12),
        ),
      ));
      lastEnd = matchIdx + query.length;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ));
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88,
            ),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isUser ? _pink : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isUser ? 22 : 6),
                bottomRight: Radius.circular(isUser ? 4 : 22),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.pendingImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.pendingImage!.path),
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 180,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.broken_image, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ),
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isUser ? Colors.white : const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends AnimatedWidget {
  const _TypingIndicator({required super.listenable});

  Animation<double> get _animation =>
      listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final value = _animation.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(
                  color: const Color(0xFFE8ECF1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    (value >= 0.5 ? value - 0.5 : 0.5 - value) *
                        -4,
                  ),
                  child: Opacity(
                    opacity: 0.3 + value * 0.7,
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(
                          right: i < 2 ? 4 : 0),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pink,
                      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: Color(0xFFF8FAFC))),
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
                child: Icon(icon,
                    color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

