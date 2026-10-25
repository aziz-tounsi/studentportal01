import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../../core/router/app_router.dart';
import '../../providers/suggestions_provider.dart';
import '../../widgets/ios_loader.dart';

class WriteSuggestionScreen extends ConsumerStatefulWidget {
  const WriteSuggestionScreen({super.key});

  @override
  ConsumerState<WriteSuggestionScreen> createState() =>
      _WriteSuggestionScreenState();
}

/// Suggestion types relevant for Tunisian students
const Map<String, String> suggestionTypes = {
  'reclamation_note': 'Réclamation de note',
  'absence': 'Absence / Justification',
  'emploi_temps': 'Emploi du temps',
  'inscription': 'Inscription / Réinscription',
  'paiement': 'Paiement / Frais de scolarité',
  'orientation': 'Orientation / Changement de filière',
  'bourse': 'Bourse / Aide sociale',
  'transport': 'Transport / Hébergement',
  'restauration': 'Restauration universitaire',
  'bibliotheque': 'Bibliothèque / Ressources',
  'vie_universitaire': 'Vie universitaire / Activités',
  'infrastructure': 'Infrastructure / Équipements',
  'securite': 'Sécurité / Hygiène',
  'autre': 'Autre',
};

/// Get icon for suggestion type
IconData getTypeIcon(String type) {
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

/// Get color for suggestion type
Color getTypeColor(String type) {
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

class _WriteSuggestionScreenState extends ConsumerState<WriteSuggestionScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<PlatformFile> _attachedFiles = [];
  bool _isSubmitting = false;
  String _selectedType = 'autre';

  @override
  void deactivate() {
    dismissAllOverlaysAndPopups();
    super.deactivate();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorSelectingFiles}: $e'),
          ),
        );
      }
    }
  }

  Future<void> _submitSuggestion() async {
    final l10n = AppLocalizations.of(context);
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillDescription)),
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
              final storePath = '$userId/${timestamp}_${file.name}';

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
            debugPrint('Error uploading file: $e');
          }
        }
      }

      // Create suggestion using repository
      final typesMap = l10n.suggestionTypesList;
      await ref
          .read(suggestionRepositoryProvider)
          .createSuggestion(
            title: typesMap[_selectedType] ?? l10n.suggestions,
            body: _contentController.text.trim(),
            suggestionType: _selectedType,
            attachmentUrls: attachmentUrls,
            attachmentNames: attachmentNames,
            attachmentTypes: attachmentTypes,
          );

      // Refresh list
      ref.invalidate(suggestionsProvider);

      if (mounted) {
        context.go('/suggestions');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.suggestionSubmittedSuccess),
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

  /// Build premium dropdown type selector
  Widget _buildTypeSelector(AppLocalizations l10n) {
    final selectedColor = getTypeColor(_selectedType);
    final selectedIcon = getTypeIcon(_selectedType);
    final typesMap = l10n.suggestionTypesList;
    final selectedLabel = typesMap[_selectedType] ?? l10n.selectType;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: PopupMenuThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 8,
          ),
        ),
        child: PopupMenuButton<String>(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          onSelected: (value) => setState(() => _selectedType = value),
          offset: const Offset(0, 56),
          itemBuilder: (context) => typesMap.entries.map((entry) {
            final typeColor = getTypeColor(entry.key);
            final typeIcon = getTypeIcon(entry.key);
            final isSelected = _selectedType == entry.key;

            return PopupMenuItem<String>(
              value: entry.key,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? typeColor : Colors.grey[800],
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: typeColor, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selectedColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(selectedIcon, color: selectedColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.suggestionTypeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Custom Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        dismissAllOverlaysAndPopups();
                        context.go('/suggestions');
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Icon(
                            isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                            color: Colors.grey[700],
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.newSuggestion,
                            style: ArabicTypography.headerStyle(
                              context,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[900],
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            l10n.shareIdeas,
                            style: ArabicTypography.subtitleStyle(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Suggestion Type Selection - Modern Glassy Radio Grid
                            Text(
                              l10n.suggestionTypeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTypeSelector(l10n),
                            const SizedBox(height: 24),
                            // Description Field
                            Text(
                              l10n.descriptionLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF64748B).withValues(alpha: 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _contentController,
                                maxLines: 6,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1F2937),
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  hintText: l10n.describeSuggestionHint,
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(20),
                                ),
                              ),
                            ),
                             const SizedBox(height: 24),
                             // Attached files preview - show image previews for images, icons for documents
                             if (_attachedFiles.isNotEmpty) ...[
                               const SizedBox(height: 16),
                               Wrap(
                                 spacing: 12,
                                 runSpacing: 12,
                                 children: [
                                   ...List.generate(_attachedFiles.length, (index) {
                                     final file = _attachedFiles[index];
                                     final isImage = ['jpg', 'jpeg', 'png', 'gif']
                                         .contains(file.extension?.toLowerCase());
                                     
                                      return Stack(
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: isImage 
                                                  ? null 
                                                  : Colors.grey[100] ?? Colors.transparent,
                                              border: isImage 
                                                ? null
                                                  : Border.all(
                                                      color: Colors.grey[300]!,
                                                      width: 1,
                                                    ),
                                               image: isImage
                                                   ? DecorationImage(
                                                       image: file.bytes != null 
                                                           ? MemoryImage(file.bytes!) as ImageProvider
                                                           : const AssetImage('assets/images/placeholder.png'), // Placeholder
                                                       fit: BoxFit.cover,
                                                     )
                    : null,
                                            ),
                                              child: !isImage
                                                  ? Column(
                                                     mainAxisAlignment: MainAxisAlignment.center,
                                                     children: [
                                                       Icon(
                                                         Icons.insert_drive_file_rounded,
                                                         size: 28,
                                                         color: Colors.grey[600],
                                                       ),
                                                       const SizedBox(height: 4),
                                                       Text(
                                                         file.extension?.toUpperCase() ?? 'FILE',
                                                         style: TextStyle(
                                                           fontSize: 10,
                                                           color: Colors.grey[600],
                                                           fontWeight: FontWeight.w500,
                                                         ),
                                                       ),
                                                     ],
                                                   )
                                                 : null,
                                           ),
                                           Positioned(
                                             top: 4,
                                             right: 4,
                                             child: GestureDetector(
                                               onTap: () {
                                                 setState(() {
                                                   _attachedFiles.removeAt(index);
                                                 });
                                               },
                                               child: Container(
                                                 width: 22,
                                                 height: 22,
                                                 decoration: BoxDecoration(
                                                   color: Colors.black.withValues(alpha: 0.6),
                                                   shape: BoxShape.circle,
                                                 ),
                                                 child: const Icon(
                                                   Icons.close,
                                                   color: Colors.white,
                                                   size: 14,
                                                 ),
                                               ),
                                             ),
                                           ),
                                         ],
                                       );
                                     }),
                                     // Add more files button
                                     GestureDetector(
                                       onTap: _pickFiles,
                                       child: Container(
                                         width: 80,
                                         height: 80,
                                         decoration: BoxDecoration(
                                           borderRadius: BorderRadius.circular(12),
                                           color: Colors.grey[200],
                                         ),
                                         child: Icon(
                                           Icons.add_rounded,
                                           color: Colors.grey[600],
                                           size: 36,
                                         ),
                                       ),
                                     ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                             // Action buttons
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20)
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 54,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF2D78),
                                            Color(0xFFFF5CA0),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFFF2D78,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _isSubmitting
                                              ? null
                                              : _submitSuggestion,
                                          borderRadius: BorderRadius.circular(24),
                                          child: Center(
                                            child: _isSubmitting
                                                ? const IosLoader(size: 24, color: Colors.white)
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Transform.flip(
                                                        flipX: isRtl,
                                                        child: const Icon(
                                                          Icons.send_rounded,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        l10n.send,
                                                        style: ArabicTypography.buttonStyle(
                                                          context,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white,
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
