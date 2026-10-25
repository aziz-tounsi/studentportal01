// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/announcements_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/detail_modal_sheet.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/notifications_screen_skeleton.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _searchWidthAnimation;
  late Animation<double> _iconSizeAnimation;

  static const Color _accentColor = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchWidthAnimation = Tween<double>(begin: 44, end: 200).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _iconSizeAnimation = Tween<double>(begin: 22, end: 18).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _animationController.forward();
        Future.delayed(const Duration(milliseconds: 150), () {
          _searchFocusNode.requestFocus();
        });
      } else {
        _animationController.reverse();
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  // Build the animated header
  Widget _buildAnimatedHeader() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final slideValue = _animationController.value;
        final fadeOut = 1.0 - slideValue;
        final fadeIn = slideValue;

        return SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Normal header - slides out to left and fades
              Transform.translate(
                offset: Offset(-80 * slideValue, 0),
                child: Opacity(
                  opacity: fadeOut.clamp(0.0, 1.0),
                  child: Row(
                    children: [
                      // Icon with scale animation
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
                              colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context).notifications,
                              style: ArabicTypography.headerStyle(
                                context,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey[900],
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context).notificationsSubtitle,
                              style: ArabicTypography.subtitleStyle(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Search button
                      GestureDetector(
                        onTap: _toggleSearch,
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
                      // Cancel button
                      GestureDetector(
                        onTap: _toggleSearch,
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
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 18),
                              Icon(
                                Icons.search_rounded,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  cursorColor: Colors.grey[600],
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                  style: ArabicTypography.bodyStyle(
                                    context,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context).search,
                                    hintStyle: ArabicTypography.bodyStyle(
                                      context,
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: Container(
                                    margin: const EdgeInsetsDirectional.only(end: 8),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey[600],
                                      size: 14,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 18),
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

  // Normal header with icon, title and search button
  Widget _buildNormalHeader() {
    return Row(
      children: [
        // Icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).notifications,
                style: ArabicTypography.headerStyle(
                  context,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[900],
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).notificationsSubtitle,
                style: ArabicTypography.subtitleStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Search button
        GestureDetector(
          onTap: _toggleSearch,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.search_rounded,
              color: Colors.grey[700],
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  // Search header with full-width search bar
  Widget _buildSearchHeader() {
    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: _toggleSearch,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              color: _accentColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Search field
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search_rounded, color: _accentColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    cursorColor: Colors.grey[600],
                    onChanged: (value) => setState(() => _searchQuery = value),
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
                      ),
                      filled: false,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: Icon(
                        Icons.cancel_rounded,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final announcementsAsync = ref.watch(globalAnnouncementsProvider);
    final isRefreshing = ref.watch(notificationsRefreshingProvider);

    // Show loading if auth is still loading
    final isAuthLoading = authState.isLoading;

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
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(notificationsRefreshingProvider.notifier).state = true;
            try {
              // ignore: unused_result
              await ref.refresh(globalAnnouncementsProvider.future);
            } finally {
              ref.read(notificationsRefreshingProvider.notifier).state = false;
            }
          },
          color: const Color(0xFFFF2D78),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: _buildAnimatedHeader(),
                ),
              ),

            // Notifications List
            // Show loading if auth is still loading
            if (isAuthLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: IosLoader(),
                  ),
                ),
              )
            else if (isRefreshing)
              const NotificationsCardsSkeleton()
            else
            announcementsAsync.when(
              loading: () => const NotificationsCardsSkeleton(),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${l10n.error}: $e',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (announcements) {
                // Filter announcements by search
                var filtered = announcements;
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filtered = announcements.where((a) {
                    final localizedTitle = l10n
                        .localizeAnnouncementTitle(a.announcementType, a.title)
                        .toLowerCase();
                    final localizedBody = l10n
                        .localizeAnnouncementBody(
                          a.announcementType,
                          a.payload,
                          a.body,
                        )
                        .toLowerCase();
                    final localizedKeyInfo = _extractKeyInfo(
                      a.announcementType,
                      a.payload,
                      a.body,
                    ).toLowerCase();
                    final localizedType = _getTypeLabel(
                      a.announcementType,
                    ).toLowerCase();
                    final localizedSender = l10n
                        .localizeSenderLabel(a.senderLabel)
                        .toLowerCase();
                    return a.title.toLowerCase().contains(query) ||
                        a.body.toLowerCase().contains(query) ||
                        localizedTitle.contains(query) ||
                        localizedBody.contains(query) ||
                        localizedKeyInfo.contains(query) ||
                        localizedType.contains(query) ||
                        localizedSender.contains(query) ||
                        (a.senderLabel?.toLowerCase().contains(query) ??
                            false) ||
                        (a.announcementType?.toLowerCase().contains(query) ??
                            false);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF2B6D), Color(0xFFE11D48)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF2B6D).withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.notifications_off_rounded,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              l10n.noNotifications,
                              textAlign: TextAlign.center,
                              style: ArabicTypography.headerStyle(
                                context,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.notificationsAppearHere,
                              textAlign: TextAlign.center,
                              style: ArabicTypography.bodyStyle(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 124 + MediaQuery.of(context).padding.bottom),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildNotificationCard(filtered[index]),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(dynamic announcement) {
    final l10n = AppLocalizations.of(context);
    final isImportant = announcement.isImportant;
    final isPinned = announcement.isPinned;
    final color = _getTypeColor(announcement.announcementType);
    final icon = _getTypeIcon(announcement.announcementType);
    final typeLabel = _getTypeLabel(announcement.announcementType);
    final localizedTitle = l10n.localizeAnnouncementTitle(
      announcement.announcementType,
      announcement.title,
    );
    final localizedBody = l10n.localizeAnnouncementBody(
      announcement.announcementType,
      announcement.payload,
      announcement.body,
    );
    final keyInfo = _extractKeyInfo(
      announcement.announcementType,
      announcement.payload,
      announcement.body,
    );
    
    // Check for non-image attachments (documents)
    final hasDocumentAttachment = announcement.attachments.any(
      (att) => !_isImageFile(att.fileUrl),
    );
    // Count images and documents separately
    final imageCount = announcement.attachments.where(
      (att) => _isImageFile(att.fileUrl),
    ).length;
    final documentCount = announcement.attachments.where(
      (att) => !_isImageFile(att.fileUrl),
    ).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showAnnouncementDetail(announcement),
        child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with icon, title, and badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [color, color.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      // Type label and Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            if (announcement.announcementType == 'general')
                              const SizedBox(height: 4),
                            Text(
                              localizedTitle,
                              style: TextStyle(
                                fontSize: announcement.announcementType == 'general' ? 12 : 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1F2937),
                                letterSpacing: -0.3,
                                height: 1.0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Key info subtitle - only show if not empty
                            if (isPinned || keyInfo.isNotEmpty)
                              Transform.translate(
                                offset: const Offset(0, -10),
                                child: Row(
                                  children: [
                                    if (keyInfo.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          keyInfo,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                            height: 1.0,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (isPinned)
                                      _buildBadge(l10n.pinnedLabel, const Color(0xFFFF2D78), Icons.push_pin),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Badges row
                  if (isImportant || hasDocumentAttachment) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isImportant)
                          _buildBadge(
                            l10n.importantLabel,
                            Colors.red,
                            Icons.priority_high,
                          ),
                        if (hasDocumentAttachment)
                          _buildBadge(
                            l10n.attachment,
                            Colors.purple,
                            Icons.attach_file,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Body content with small image thumbnail at end
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          localizedBody,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Small image thumbnail at end of body
                      if (imageCount > 0) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _showImageViewer(
                            announcement.attachments
                                .where((att) => _isImageFile(att.fileUrl))
                                .map((att) => att.fileUrl)
                                .toList(),
                            0,
                          ),
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
                                    announcement.attachments
                                        .firstWhere((att) => _isImageFile(att.fileUrl))
                                        .fileUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
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
                                  // Show image count badge if multiple
                                  if (imageCount > 1)
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+${imageCount - 1}',
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
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Footer with sender and time
                  Row(
                    children: [
                      // Sender info
                      if (announcement.senderLabel != null) ...[
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.localizeSenderLabel(announcement.senderLabel),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      // Timestamp
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(announcement.publishedAt),
                        style: TextStyle(
                          fontSize: 10,
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

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(String url, String? name) {
    final l10n = AppLocalizations.of(context);
    final isImage = _isImageFile(url);

    return GestureDetector(
      onTap: () => _openAttachment(url),
      child: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 80,
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
                        height: 60,
                        color: Colors.grey[100],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Text(
                              l10n.imageUnavailable,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.openLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getAttachmentIcon(url),
                    size: 18,
                    color: Colors.purple[600],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _getCleanFileName(name, url),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: Colors.purple[600],
                  ),
                ],
              ),
            ),
    );
  }

  bool _isImageFile(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  Widget _buildDetailAttachment(String url, String? name) {
    final l10n = AppLocalizations.of(context);
    final isImage = _isImageFile(url);

    return GestureDetector(
      onTap: () => _openAttachment(url),
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
                        l10n.imageUnavailable,
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
                      _getAttachmentIcon(url),
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
                          _getCleanFileName(name, url),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.purple[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.tapToDownload,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.download_rounded,
                    size: 24,
                    color: Colors.purple[700],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAnnouncementDetail(dynamic announcement) {
    final l10n = AppLocalizations.of(context);
    final color = _getTypeColor(announcement.announcementType);
    final icon = _getTypeIcon(announcement.announcementType);
    final typeLabel = _getTypeLabel(announcement.announcementType);
    final localizedTitle = l10n.localizeAnnouncementTitle(
      announcement.announcementType,
      announcement.title,
    );
    final localizedBody = l10n.localizeAnnouncementBody(
      announcement.announcementType,
      announcement.payload,
      announcement.body,
    );
    final keyInfo = _extractKeyInfo(
      announcement.announcementType,
      announcement.payload,
      announcement.body,
    );

    DetailModalSheet.show(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                          // Header with icon
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [color, color.withValues(alpha: 0.7)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(icon, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        typeLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.formatAnnouncementDateTime(
                                        announcement.publishedAt,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Badges
                          if (announcement.isPinned || announcement.isImportant || announcement.attachments.any((att) => !_isImageFile(att.fileUrl)))
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (announcement.isPinned)
                                  _buildBadge(l10n.pinnedLabel, const Color(0xFFFF2D78), Icons.push_pin),
                                if (announcement.isImportant)
                                  _buildBadge(
                                    l10n.importantLabel,
                                    Colors.red,
                                    Icons.priority_high,
                                  ),
                                if (announcement.attachments.any((att) => !_isImageFile(att.fileUrl)))
                                  _buildBadge(
                                    l10n.attachment,
                                    Colors.purple,
                                    Icons.attach_file,
                                  ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          // Key info summary if available
                          if (keyInfo.isNotEmpty) ...[
                            Text(
                              keyInfo,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          // Body content
                          Text(
                            localizedBody,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                          // Attachments - show all from attachments list
                          if (announcement.attachments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...announcement.attachments.map(
                              (att) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildDetailAttachment(
                                  att.fileUrl,
                                  att.effectiveName,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Title
                          Text(
                            localizedTitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                              letterSpacing: -0.5,
                            ),
                          ),
                          // Sender info in styled container
                          if (announcement.senderLabel != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.sentByLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          l10n.localizeSenderLabel(
                                            announcement.senderLabel,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).cannotOpenFile),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageViewer(List<String> imageUrls, int initialIndex) {
    final l10n = AppLocalizations.of(context);
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
                    imageUrls[initialIndex],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            l10n.imageUnavailable,
                            style: const TextStyle(color: Colors.white54),
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
              // Close button
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
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Image counter if multiple
              if (imageUrls.length > 1)
                Positioned(
                  top: 50,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${initialIndex + 1} / ${imageUrls.length}',
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

  IconData _getAttachmentIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return Icons.slideshow_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  String _getAttachmentName(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.last;
      return Uri.decodeComponent(path);
    } catch (e) {
      return AppLocalizations.of(context).attachedFile;
    }
  }

  /// Get clean display name for file attachments
  /// Uses custom name if provided, otherwise generates a friendly name based on file type
  String _getCleanFileName(String? customName, String url) {
    return AppLocalizations.of(context).getCleanAttachmentFileName(
      customName,
      url,
    );
  }

  String _getTypeLabel(String? type) {
    return AppLocalizations.of(context).getAnnouncementTypeLabel(type);
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'teacher_absent':
        return const Color(0xFFEF4444);
      case 'room_change':
        return const Color(0xFF3B82F6);
      case 'exam':
        return const Color(0xFFF59E0B);
      case 'reminder':
        return const Color(0xFF8B5CF6);
      case 'closure':
        return const Color(0xFFEC4899);
      case 'trip':
        return const Color(0xFF10B981);
      case 'party':
        return const Color(0xFFF97316);
      case 'payment':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'teacher_absent':
        return Icons.person_off_rounded;
      case 'room_change':
        return Icons.meeting_room_rounded;
      case 'exam':
        return Icons.quiz_rounded;
      case 'reminder':
        return Icons.notifications_active_rounded;
      case 'closure':
        return Icons.lock_rounded;
      case 'trip':
        return Icons.directions_bus_rounded;
      case 'party':
        return Icons.celebration_rounded;
      case 'payment':
        return Icons.payment_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  /// Extracts key information from announcement based on type and payload
  String _extractKeyInfo(String? type, Map<String, dynamic> payload, String body) {
    return AppLocalizations.of(context).extractAnnouncementKeyInfo(
      type,
      payload,
      body,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    String lang = 'fr';
    try {
      lang = Localizations.localeOf(context).languageCode;
    } catch (_) {}

    if (lang == 'ar') {
      if (difference.inMinutes < 60) {
        return 'منذ ${difference.inMinutes} د';
      } else if (difference.inHours < 24) {
        return 'منذ ${difference.inHours} س';
      } else if (difference.inDays < 7) {
        return 'منذ ${difference.inDays} يوم';
      } else {
        return ArabicTypography.toLatinDigits(DateFormat('d MMM', 'ar').format(time));
      }
    } else if (lang == 'en') {
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('d MMM', 'en').format(time);
      }
    }

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return DateFormat('d MMM', 'fr_FR').format(time);
    }
  }
}
