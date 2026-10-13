// ignore_for_file: unused_element, unused_field, unused_import

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/suggestions_provider.dart';
import '../../widgets/detail_modal_sheet.dart';
import 'write_suggestion_screen.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/suggestions_screen_skeleton.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _searchAnimationController;
  late Animation<double> _searchWidthAnimation;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  List<PlatformFile> _attachedFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _searchWidthAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchAnimationController.forward();
        _searchFocusNode.requestFocus();
      } else {
        _searchAnimationController.reverse();
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestionsAsync = ref.watch(suggestionsProvider);
    final isRefreshing = ref.watch(suggestionsRefreshingProvider);

    return Stack(
      children: [
        Container(
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
            bottom: false,
            child: RefreshIndicator(
              color: const Color(0xFFFF2D78),
              onRefresh: () async {
                ref.read(suggestionsRefreshingProvider.notifier).state = true;
                try {
                  await ref.refresh(suggestionsProvider.future);
                } finally {
                  ref.read(suggestionsRefreshingProvider.notifier).state = false;
                }
              },
              child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Header with animated search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: _buildAnimatedHeader(l10n),
                  ),
                ),

                // Content
                if (isRefreshing) ...[
                  const SuggestionsCardsSkeleton(),
                ] else ...[
                suggestionsAsync.when(
                  data: (suggestions) {
                    // Apply filters and search
                    var filtered = suggestions.where((s) {
                      // Filter by status
                      bool matchesFilter = true;
                      switch (_selectedFilter) {
                        case 'pending':
                          // 'sent' is the DB enum value for pending/unread suggestions
                          matchesFilter =
                              (s.status == 'pending' || s.status == 'sent') &&
                              !s.isRead;
                          break;
                        case 'read':
                          matchesFilter = s.isRead;
                          break;
                        case 'replied':
                          matchesFilter = s.replies.isNotEmpty;
                          break;
                      }

                      // Apply search
                      if (_searchQuery.isNotEmpty) {
                        final typeLabel = _getTypeLabel(
                          s.suggestionType,
                          l10n,
                        ).toLowerCase();
                        final dateStr = _formatDate(s.createdAt, l10n.locale.languageCode).toLowerCase();
                        return matchesFilter &&
                            (s.title.toLowerCase().contains(_searchQuery) ||
                                s.body.toLowerCase().contains(_searchQuery) ||
                                typeLabel.contains(_searchQuery) ||
                                dateStr.contains(_searchQuery));
                      }

                      return matchesFilter;
                    }).toList();

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (filtered.isNotEmpty) ...[
                            ...filtered.map(
                              (suggestion) => _buildSuggestionCard(suggestion, l10n),
                            ),
                          ] else if (suggestions.isEmpty) ...[
                            const SizedBox(height: 40),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            size: 40,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            l10n.noSuggestions,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF94A3B8),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            l10n.suggestionsSubtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          GestureDetector(
                                            onTap: () => context.go('/write-suggestion'),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFFFF2D78), Color(0xFFFF5CA0)],
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFFF2D78).withValues(alpha: 0.4),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    l10n.newSuggestion,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                l10n.noResults,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black.withOpacity(0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    );
                  },
                  loading: () => const SuggestionsCardsSkeleton(),
                  error: (error, stack) => SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Erreur: $error',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
        ),
        // FloatingActionButton positioned manually - only show when there are suggestions
        if (suggestionsAsync.hasValue && suggestionsAsync.value!.isNotEmpty)
          Positioned(
            right: 24,
            bottom: 160,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/write-suggestion'),
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2D78), Color(0xFFFF5CA0)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D78).withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNewSuggestionCard(BuildContext context, AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nouvelle suggestion',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                decoration: InputDecoration(
                  hintText: 'Titre',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
                decoration: InputDecoration(
                  hintText: 'Décrivez votre suggestion...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
              // File attachments
              if (_attachedFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...List.generate(_attachedFiles.length, (index) {
                  final file = _attachedFiles[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            file.name,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _attachedFiles.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Joindre'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitSuggestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D78),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const IosLoader(size: 20, color: Colors.white)
                          : const Text(
                              'Envoyer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
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
    );
  }

  Widget _buildSuggestionsListHeader(BuildContext context, int count) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.locale.languageCode == 'ar';
    return Row(
      children: [
        Text(
          l10n.mySuggestions,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            isAr ? '$count اقتراح' : '$count suggestion${count > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(Suggestion suggestion, AppLocalizations l10n) {
    final color = _getTypeColor(suggestion.suggestionType);
    final icon = _getTypeIcon(suggestion.suggestionType);
    final typeLabel = _getTypeLabel(suggestion.suggestionType, l10n, suggestion.title);
    final imageAttachments = suggestion.attachments
        .where(_isImageAttachment)
        .toList();
    final hasDocumentAttachment = suggestion.attachments.any(
      (att) => !_isImageAttachment(att),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showSuggestionDetail(suggestion),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Container(
                         width: 44,
                         height: 44,
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                             colors: [color, color.withOpacity(0.7)],
                           ),
                           borderRadius: BorderRadius.circular(12),
                           boxShadow: [
                             BoxShadow(
                               color: color.withOpacity(0.3),
                               blurRadius: 8,
                               offset: const Offset(0, 3),
                             ),
                           ],
                         ),
                         child: Icon(icon, color: Colors.white, size: 22),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               typeLabel,
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.w900,
                                 color: const Color(0xFF1F2937),
                                 letterSpacing: -0.3,
                                 height: 1.0,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                             const SizedBox(height: 6),
                             Text(
                               _formatDate(suggestion.createdAt, l10n.locale.languageCode),
                               style: TextStyle(
                                 fontSize: 12,
                                 fontWeight: FontWeight.w600,
                                 color: Colors.grey[600],
                                 height: 1.0,
                               ),
                             ),
                           ],
                         ),
                       ),
                     ],
                    ),
                    const SizedBox(height: 12),
                   Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Expanded(
                         child: _buildHighlightedText(
                           suggestion.body,
                           _searchQuery,
                           TextStyle(
                             fontSize: 13,
                             fontWeight: FontWeight.w500,
                             color: Colors.grey[700],
                             height: 1.4,
                           ),
                           maxLines: 3,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       if (imageAttachments.isNotEmpty) ...[
                         const SizedBox(width: 10),
                         _buildImageThumbnail(
                           imageAttachments: imageAttachments,
                           initialIndex: 0,
                         ),
                       ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (hasDocumentAttachment) ...[
                        _buildBadge(
                          l10n.attachment,
                          Colors.purple,
                        ),
                      ],
                      Text(
                        _getRelativeTime(suggestion.createdAt, l10n.locale.languageCode),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
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
  }

  String _getRelativeTime(DateTime date, [String? langCode]) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final lang = langCode ?? 'fr';
    if (diff.inMinutes < 60) {
      if (diff.inMinutes <= 0) {
        if (lang == 'ar') return 'الآن';
        if (lang == 'en') return 'Just now';
        return 'À l\'instant';
      }
      if (lang == 'ar') return 'منذ ${diff.inMinutes} د';
      if (lang == 'en') return '${diff.inMinutes}m ago';
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      if (lang == 'ar') return 'منذ ${diff.inHours} س';
      if (lang == 'en') return '${diff.inHours}h ago';
      return 'Il y a ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      if (lang == 'ar') return 'منذ ${diff.inDays} ي';
      if (lang == 'en') return '${diff.inDays}d ago';
      return 'Il y a ${diff.inDays} j';
    }
    return '';
  }

  // Helper methods
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif'],
      );

      if (result != null) {
        setState(() {
          _attachedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection des fichiers: $e'),
          ),
        );
      }
    }
  }

  Future<void> _submitSuggestion() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) throw Exception('Non authentifié');

      // Upload files if any
      List<String>? attachmentUrls;
      List<String>? attachmentNames;
      List<String>? attachmentTypes;

      if (_attachedFiles.isNotEmpty) {
        attachmentUrls = [];
        attachmentNames = [];
        attachmentTypes = [];

        for (final file in _attachedFiles) {
          try {
            final bytes = file.bytes;
            if (bytes != null) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final storePath = '$userId/$timestamp\_${file.name}';

              await supabase.storage
                  .from('suggestions')
                  .uploadBinary(storePath, bytes);

              final url = supabase.storage
                  .from('suggestions')
                  .getPublicUrl(storePath);

              attachmentUrls.add(url);
              attachmentNames.add(file.name);
              attachmentTypes.add(file.extension ?? '');
            }
          } catch (e) {
            print('Error uploading file: $e');
          }
        }
      }

      // Create suggestion using repository
      await ref
          .read(suggestionRepositoryProvider)
          .createSuggestion(
            title: _titleController.text.trim(),
            body: _contentController.text.trim(),
            attachmentUrls: attachmentUrls,
            attachmentNames: attachmentNames,
            attachmentTypes: attachmentTypes,
          );

      // Clear form
      _titleController.clear();
      _contentController.clear();
      setState(() {
        _attachedFiles.clear();
      });

      // Refresh list
      ref.invalidate(suggestionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suggestion envoyée avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuggestionDetail(Suggestion suggestion) {
    final l10n = AppLocalizations.of(context);
    DetailModalSheet.show(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Expanded(
                child: Text(
                  _getDetailTitle(suggestion, l10n),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDate(suggestion.createdAt, l10n.locale.languageCode),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Body
          Text(
            suggestion.body,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
          // Attachments
          if (suggestion.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...suggestion.attachments.map((att) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildDetailAttachment(att),
              );
            }),
          ],
          // Replies
          if (suggestion.replies.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.adminResponse,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            ...suggestion.replies.map((reply) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.translate('administration'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(reply.createdAt, l10n.locale.languageCode),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reply.replyText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImageThumbnail({
    required List<SuggestionAttachment> imageAttachments,
    required int initialIndex,
  }) {
    return GestureDetector(
      onTap: () => _showImageViewer(imageAttachments, initialIndex),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageAttachments[initialIndex].fileUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: Colors.grey[400],
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: IosLoader(size: 14),
                    ),
                  );
                },
              ),
              if (imageAttachments.length > 1)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${imageAttachments.length - 1}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailAttachment(SuggestionAttachment attachment) {
    final isImage = _isImageAttachment(attachment);
    final url = attachment.fileUrl;

    return GestureDetector(
      onTap: () {
        if (isImage) {
          _showImageViewer([attachment], 0);
        } else {
          _openAttachment(url);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[100],
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Image non disponible',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getAttachmentIcon(attachment),
                      size: 24,
                      color: Colors.purple[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCleanFileName(attachment),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.purple[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Appuyez pour télécharger',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.download_rounded, color: Colors.purple[600]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showImageViewer(
    List<SuggestionAttachment> imageAttachments,
    int initialIndex,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageAttachments[initialIndex].fileUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Image non disponible',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
              if (imageAttachments.length > 1)
                Positioned(
                  top: 50,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${initialIndex + 1} / ${imageAttachments.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le fichier'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isImageAttachment(SuggestionAttachment attachment) {
    final type = attachment.fileType?.toLowerCase() ?? '';
    return type.startsWith('image/') ||
        _isImagePath(type) ||
        _isImagePath(attachment.fileName) ||
        _isImagePath(attachment.fileUrl);
  }

  bool _isImagePath(String value) {
    final parsed = Uri.tryParse(value);
    final lower = (parsed?.path.isNotEmpty == true ? parsed!.path : value)
        .toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  IconData _getAttachmentIcon(SuggestionAttachment attachment) {
    final value =
        '${attachment.fileName} ${attachment.fileType} ${attachment.fileUrl}'
            .toLowerCase();
    if (value.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (value.contains('doc')) return Icons.description_rounded;
    if (value.contains('xls')) return Icons.table_chart_rounded;
    if (value.contains('ppt')) return Icons.slideshow_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String _getCleanFileName(SuggestionAttachment attachment) {
    if (attachment.fileName.isNotEmpty) return attachment.fileName;

    try {
      final uri = Uri.parse(attachment.fileUrl);
      if (uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
    } catch (_) {
      // Fall through to generic label.
    }

    return 'Fichier joint';
  }

    String _getDetailTitle(Suggestion suggestion, AppLocalizations l10n) {
    final typeCandidate = suggestion.suggestionType.isNotEmpty && suggestion.suggestionType != 'general'
        ? suggestion.suggestionType
        : suggestion.title;
    final localized = l10n.getSuggestionType(typeCandidate);
    if (localized.isNotEmpty && !localized.startsWith('st_')) {
      return localized;
    }
    final localizedFromTitle = l10n.getSuggestionType(suggestion.title);
    if (localizedFromTitle.isNotEmpty && !localizedFromTitle.startsWith('st_')) {
      return localizedFromTitle;
    }
    return suggestion.title.isNotEmpty ? suggestion.title : l10n.suggestions;
  }

  String _getTypeLabel(String type, [AppLocalizations? l10n, String? fallbackTitle]) {
    if (l10n != null) {
      if ((type.isEmpty || type == 'general') && fallbackTitle != null && fallbackTitle.isNotEmpty) {
        return l10n.getShortSuggestionType(fallbackTitle);
      }
      return l10n.getShortSuggestionType(type);
    }
    switch (type) {
      case 'reclamation_note':
        return 'Note';
      case 'absence':
        return 'Absence';
      case 'emploi_temps':
        return 'EDT';
      case 'inscription':
        return 'Inscription';
      case 'paiement':
        return 'Paiement';
      case 'stage':
        return 'Stage/PFE';
      case 'orientation':
        return 'Orientation';
      case 'bourse':
        return 'Bourse';
      case 'transport':
        return 'Transport';
      case 'restauration':
        return 'Resto';
      case 'bibliotheque':
        return 'Biblio';
      case 'vie_universitaire':
        return 'Vie univ.';
      case 'infrastructure':
        return 'Infra.';
      case 'securite':
        return 'Sécurité';
      case 'autre':
        return 'Autre';
      default:
        return 'Général';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'reclamation_note':
        return Icons.grading_rounded;
      case 'absence':
        return Icons.event_busy_rounded;
      case 'emploi_temps':
        return Icons.calendar_month_rounded;
      case 'inscription':
        return Icons.app_registration_rounded;
      case 'paiement':
        return Icons.payment_rounded;
      case 'orientation':
        return Icons.explore_rounded;
      case 'bourse':
        return Icons.school_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'restauration':
        return Icons.restaurant_rounded;
      case 'bibliotheque':
        return Icons.local_library_rounded;
      case 'vie_universitaire':
        return Icons.groups_rounded;
      case 'infrastructure':
        return Icons.apartment_rounded;
      case 'securite':
        return Icons.security_rounded;
      case 'autre':
        return Icons.more_horiz_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'reclamation_note':
        return const Color(0xFFEF4444);
      case 'absence':
        return const Color(0xFFF59E0B);
      case 'emploi_temps':
        return const Color(0xFF3B82F6);
      case 'inscription':
        return const Color(0xFF8B5CF6);
      case 'paiement':
        return const Color(0xFF10B981);
      case 'stage':
        return const Color(0xFF6366F1);
      case 'orientation':
        return const Color(0xFFEC4899);
      case 'bourse':
        return const Color(0xFF14B8A6);
      case 'transport':
        return const Color(0xFF78716C);
      case 'restauration':
        return const Color(0xFFEAB308);
      case 'bibliotheque':
        return const Color(0xFF0EA5E9);
      case 'vie_universitaire':
        return const Color(0xFFA855F7);
      case 'infrastructure':
        return const Color(0xFF64748B);
      case 'securite':
        return const Color(0xFFDC2626);
      case 'autre':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _formatDate(DateTime date, [String? langCode]) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final lang = langCode ?? 'fr';

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (diff.inDays == 1) {
      if (lang == 'ar') return 'أمس';
      if (lang == 'en') return 'Yesterday';
      return 'Hier';
    } else if (diff.inDays < 7) {
      if (lang == 'ar') return '${diff.inDays} أيام';
      if (lang == 'en') return '${diff.inDays}d';
      return '${diff.inDays}j';
    } else {
      if (lang == 'ar') {
        return DateFormat('d MMMM yyyy', 'ar').format(date);
      } else if (lang == 'en') {
        return '\u200E${DateFormat('d MMMM yyyy', 'en').format(date)}\u200E';
      } else {
        return '\u200E${DateFormat('d MMMM yyyy', 'fr').format(date)}\u200E';
      }
    }
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle style, {
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final matches = <int>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx == -1) break;
      matches.add(idx);
      start = idx + q.length;
    }
    if (matches.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final matchStart in matches) {
      if (matchStart > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, matchStart)));
      }
      spans.add(
        WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D78).withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text.substring(matchStart, matchStart + q.length),
              style: style.copyWith(
                color: const Color(0xFFFF2D78),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
      cursor = matchStart + q.length;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return RichText(
      text: TextSpan(children: spans, style: style),
      maxLines: maxLines ?? 1,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  Widget _buildAnimatedHeader(AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: _searchAnimationController,
      builder: (context, child) {
        final slideValue = _searchAnimationController.value;
        final fadeOut = 1.0 - slideValue;
        final fadeIn = slideValue;

        return SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Normal header - slides out and fades
              Transform.translate(
                offset: Offset(-80 * slideValue, 0),
                child: Opacity(
                  opacity: fadeOut.clamp(0.0, 1.0),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 1.0 - (0.3 * slideValue),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lightbulb_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.suggestions,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1F2937),
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.shareIdeas,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleSearch,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            color: Colors.grey[700],
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Search bar - slides in from right
              Transform.translate(
                offset: Offset(
                  MediaQuery.of(context).size.width * (1 - slideValue),
                  0,
                ),
                child: Opacity(
                  opacity: fadeIn.clamp(0.0, 1.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleSearch,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[700],
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Search field - pill shaped
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Icon(
                                Icons.search_rounded,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  cursorColor: Colors.grey[600],
                                  onChanged: (value) => setState(
                                    () => _searchQuery = value.toLowerCase(),
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context).search,
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
