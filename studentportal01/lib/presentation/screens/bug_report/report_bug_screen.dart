import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/ios_edge_swipe_back.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/bouncy_dropdown_selector.dart';

class ReportBugScreen extends ConsumerStatefulWidget {
  const ReportBugScreen({super.key});

  @override
  ConsumerState<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends ConsumerState<ReportBugScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _selectedCategory = 'functional';
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
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        final List<PlatformFile> newFiles = [];
        for (final img in images) {
          final bytes = await img.readAsBytes();
          newFiles.add(
            PlatformFile(
              name: img.name,
              size: bytes.length,
              path: img.path,
              bytes: bytes,
            ),
          );
        }
        setState(() {
          _attachments.addAll(newFiles);
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

      final categoryLabel = _getCategoryLabel(_selectedCategory, l10n);
      final fullDesc = '[BUG REPORT - $categoryLabel]\n$desc';

      // 1. Try saving directly into the dedicated bug_reports table (for Super Admin console)
      bool savedToBugReports = false;
      try {
        await supabase.from('bug_reports').insert({
          'user_id': user?.id,
          'school_id': user?.schoolId,
          'student_name': user?.fullName,
          'student_code': user?.studentCode,
          'title': title,
          'description': desc,
          'category': _selectedCategory,
          'attachment_urls': uploadedUrls,
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
        });
        savedToBugReports = true;
      } catch (brErr) {
        debugPrint('bug_reports table insert note: $brErr');
      }

      // 2. Fallback if bug_reports table is not yet created: store tagged as bug_report
      if (!savedToBugReports) {
        try {
          await supabase.from('suggestions').insert({
            'student_id': user?.id,
            'school_id': user?.schoolId,
            'subject': title,
            'title': title,
            'message': fullDesc,
            'body': fullDesc,
            'suggestion_type': 'bug_report', // Isolated type: filtered out from student app & school admin
            'status': 'sent',
            'has_attachment': uploadedUrls.isNotEmpty,
            'student_name': user?.fullName,
            'student_code': user?.studentCode,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Fallback suggestion bug report insert error: $e');
        }
      }

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
    final items = categories.map((catKey) {
      return BouncyDropdownItem<String>(
        value: catKey,
        label: _getCategoryLabel(catKey, l10n),
        icon: _getCategoryIcon(catKey),
        color: _getCategoryColor(catKey),
      );
    }).toList();

    return BouncyDropdownSelector<String>(
      items: items,
      selectedValue: _selectedCategory,
      onSelected: (val) => setState(() => _selectedCategory = val),
      categoryTitle: l10n.bugTypeLabel,
      borderRadius: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(
                      context.horizontalPadding,
                      16,
                      context.horizontalPadding,
                      math.max(MediaQuery.of(context).padding.bottom, 24.0) + 20.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header (aligned with page cards at x = 20)
                        Row(
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
                                width: context.scaleW(44).clamp(38.0, 48.0),
                                height: context.scaleW(44).clamp(38.0, 48.0),
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
                                      size: context.scaleW(18).clamp(16.0, 20.0),
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: context.scaleW(14).clamp(10.0, 16.0)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      l10n.reportABug,
                                      style: ArabicTypography.headerStyle(
                                        context,
                                        fontSize: context.sp(24),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.reportBugSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ArabicTypography.subtitleStyle(
                                      context,
                                      fontSize: context.sp(13),
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Form Content enclosed inside rounded frosted-glass card
                        ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: EdgeInsets.all(AppResponsive.cardPadding(context, base: 26.0)),
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
                                    l10n.bugScreenshotLabel,
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
                      ],
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
}
