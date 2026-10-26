import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/suggestions_provider.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/ios_edge_swipe_back.dart';
import '../../widgets/ios_loader.dart';

class ReportBugScreen extends ConsumerStatefulWidget {
  const ReportBugScreen({super.key});

  @override
  ConsumerState<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends ConsumerState<ReportBugScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _selectedCategory = 'functional';
  bool _isCategoryDropdownOpen = false;
  final List<PlatformFile> _attachments = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'functional':
        return Icons.build_circle_rounded;
      case 'visual':
        return Icons.palette_rounded;
      case 'crash':
        return Icons.error_outline_rounded;
      case 'other':
      default:
        return Icons.more_horiz_rounded;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'functional':
        return const Color(0xFF3B82F6);
      case 'visual':
        return const Color(0xFF8B5CF6);
      case 'crash':
        return const Color(0xFFEF4444);
      case 'other':
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getCategoryLabel(String cat, AppLocalizations l10n) {
    switch (cat) {
      case 'functional':
        return l10n.bugTypeFunctional;
      case 'visual':
        return l10n.bugTypeVisual;
      case 'crash':
        return l10n.bugTypeCrash;
      case 'other':
      default:
        return l10n.bugTypeOther;
    }
  }

  Future<void> _pickScreenshots() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      debugPrint('Error picking screenshots: $e');
    }
  }

  Future<void> _submitReport(AppLocalizations l10n) async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            title.isEmpty ? l10n.bugTitleHint : l10n.bugDescHint,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final supabase = Supabase.instance.client;
      final List<String> uploadedUrls = [];

      for (int i = 0; i < _attachments.length; i++) {
        final file = _attachments[i];
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes != null) {
          final ext = file.extension ?? 'jpg';
          final filename = 'bug_reports/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
          try {
            await supabase.storage.from('suggestions').uploadBinary(
              filename,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
            );
            final publicUrl = supabase.storage.from('suggestions').getPublicUrl(filename);
            uploadedUrls.add(publicUrl);
          } catch (storageErr) {
            debugPrint('Error uploading screenshot $i: $storageErr');
          }
        }
      }

      final repo = ref.read(suggestionRepositoryProvider);
      final categoryLabel = _getCategoryLabel(_selectedCategory, l10n);
      final fullDesc = '[BUG REPORT - $categoryLabel]\n$desc';

      await repo.createSuggestion(
        title: title,
        body: fullDesc,
        suggestionType: 'autre',
        attachmentUrls: uploadedUrls,
      );

      try {
        await supabase.from('bug_reports').insert({
          'user_id': user?.id,
          'title': title,
          'description': desc,
          'category': _selectedCategory,
          'attachment_urls': uploadedUrls,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.bugReportSuccess,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        final swipeBack = IosEdgeSwipeBack.of(context);
        if (swipeBack != null) {
          swipeBack.animateBack();
        } else {
          context.go('/about');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildCategorySelector(AppLocalizations l10n) {
    const categories = ['functional', 'visual', 'crash', 'other'];
    final selectedColor = _getCategoryColor(_selectedCategory);
    final selectedIcon = _getCategoryIcon(_selectedCategory);
    final selectedLabel = _getCategoryLabel(_selectedCategory, l10n);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
          onOpened: () => setState(() => _isCategoryDropdownOpen = true),
          onCanceled: () => setState(() => _isCategoryDropdownOpen = false),
          onSelected: (value) => setState(() {
            _selectedCategory = value;
            _isCategoryDropdownOpen = false;
          }),
          offset: const Offset(0, 56),
          itemBuilder: (context) => categories.map((catKey) {
            final catColor = _getCategoryColor(catKey);
            final catIcon = _getCategoryIcon(catKey);
            final isSelected = _selectedCategory == catKey;
            final catLabel = _getCategoryLabel(catKey, l10n);

            return PopupMenuItem<String>(
              value: catKey,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(catIcon, color: catColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        catLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? catColor : Colors.grey[800],
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: catColor, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
          child: AnimatedScale(
            scale: _isCategoryDropdownOpen ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          l10n.bugTypeLabel,
                          style: TextStyle(
                            fontSize: 11.5,
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
                    child: AnimatedRotation(
                      turns: _isCategoryDropdownOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
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
                // Header (aligned with page cards at x = 20)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      BouncingWrapper(
                        shrinkScale: 0.86,
                        overshootScale: 1.10,
                        delayNavigation: false,
                        hitPadding: const EdgeInsets.symmetric(vertical: 8),
                        onTap: () {
                          final swipeBack = IosEdgeSwipeBack.of(context);
                          if (swipeBack != null) {
                            swipeBack.animateBack();
                          } else {
                            context.go('/about');
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Icon(
                                isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: const Color(0xFF1F2937),
                              ),
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
                              l10n.reportABug,
                              style: ArabicTypography.headerStyle(
                                context,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.reportBugSubtitle,
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

                // Form Content enclosed inside rounded frosted-glass card
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
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
                              // 1. Category Selector
                              Text(
                                l10n.bugTypeLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildCategorySelector(l10n),
                              const SizedBox(height: 24),

                              // 2. Title Field (Borderless inside high radius container)
                              Text(
                                l10n.bugTitleLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                  controller: _titleCtrl,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.bugTitleHint,
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 3. Description Field (Borderless inside high radius container)
                              Text(
                                l10n.bugDescLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                  controller: _descCtrl,
                                  maxLines: 6,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E293B),
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.bugDescHint,
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14.5,
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

                              // 4. Screenshots Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.addScreenshots,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[700],
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (_attachments.isNotEmpty)
                                    Text(
                                      '${_attachments.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFF2D78),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Pick Button
                              BouncingWrapper(
                                shrinkScale: 0.95,
                                overshootScale: 1.04,
                                delayNavigation: false,
                                onTap: _pickScreenshots,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF64748B).withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF2D78).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add_photo_alternate_rounded,
                                          color: Color(0xFFFF2D78),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        l10n.addScreenshots,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Image Previews (without file names)
                              if (_attachments.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: List.generate(_attachments.length, (index) {
                                    final file = _attachments[index];
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 88,
                                          height: 88,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            image: DecorationImage(
                                              image: file.bytes != null
                                                  ? MemoryImage(file.bytes!) as ImageProvider
                                                  : (file.path != null
                                                      ? FileImage(File(file.path!))
                                                      : const AssetImage('assets/images/placeholder.png')),
                                              fit: BoxFit.cover,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _attachments.removeAt(index)),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ],
                              const SizedBox(height: 32),

                              // 5. Submit Button
                              BouncingWrapper(
                                shrinkScale: 0.93,
                                overshootScale: 1.052,
                                delayNavigation: false,
                                onTap: _isSubmitting ? null : () => _submitReport(l10n),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF2D78), Color(0xFFFF5CA0)],
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF2D78).withValues(alpha: 0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _isSubmitting
                                        ? const IosLoader(color: Colors.white, size: 22)
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.send_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                l10n.submitBugReport,
                                                style: ArabicTypography.buttonStyle(
                                                  context,
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
