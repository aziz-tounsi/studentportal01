// ignore_for_file: avoid_web_libraries_in_flutter, unused_element, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart' show AppColors;
import '../../../core/utils/error_messages.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_management_service.dart';
import '../../providers/users_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/user_avatar.dart';
import '../users/user_profile_screen.dart';

/// Provider for pending password reset count (for notification badges)
final pendingPasswordResetCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final supabase = Supabase.instance.client;

  try {
    final response = await supabase
        .from('password_reset_requests')
        .select('id')
        .eq('status', 'pending');
    debugPrint('Pending password reset count: ${(response as List).length}');
    return (response as List).length;
  } catch (e) {
    debugPrint('Error fetching pending count: $e');
    return 0;
  }
});

/// Provider for password reset requests - uses data directly from the table
final passwordResetRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final supabase = Supabase.instance.client;

      try {
        debugPrint('Fetching password reset requests...');
        final response = await supabase
            .from('password_reset_requests')
            .select('*')
            .order('requested_at', ascending: false);

        debugPrint('Got ${(response as List).length} password reset requests');
        return (response as List).cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('Error fetching password reset requests: $e');
        return [];
      }
    });

class PasswordResetRequestsScreen extends ConsumerStatefulWidget {
  const PasswordResetRequestsScreen({super.key});

  @override
  ConsumerState<PasswordResetRequestsScreen> createState() =>
      _PasswordResetRequestsScreenState();
}

class _PasswordResetRequestsScreenState
    extends ConsumerState<PasswordResetRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Multi-selection state
  final Set<String> _selectedIds = <String>{};

  // Tabs: 0: En attente, 1: Approuvées, 2: Rejetées, 3: Toutes
  final List<String> _filterKeys = ['pending', 'approved', 'rejected', 'all'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIds.clear();
        });
      }
    });

    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchController.text.trim().toLowerCase();
          });
        }
      });
    });

    // Force refresh on page load
    Future.microtask(() {
      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
    int tabIndex,
  ) {
    final statusFilter = _filterKeys[tabIndex];
    return requests.where((r) {
      final status = (r['status'] as String? ?? 'pending').toLowerCase();
      final fullName = (r['full_name'] as String? ?? '').toLowerCase();
      final email = (r['email'] as String? ?? '').toLowerCase();

      // Tab status condition
      if (statusFilter != 'all' && status != statusFilter) {
        return false;
      }

      // Search query condition
      if (_searchQuery.isNotEmpty) {
        final matchesName = fullName.contains(_searchQuery);
        final matchesEmail = email.contains(_searchQuery);
        if (!matchesName && !matchesEmail) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _exportCsv(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune demande à exporter')),
      );
      return;
    }

    final rows = <List<dynamic>>[];
    rows.add([
      'ID',
      'Nom complet',
      'Email',
      'User ID',
      'Statut',
      'Date de demande',
      'Traité le',
      'Traité par',
    ]);

    final df = DateFormat('dd/MM/yyyy HH:mm');
    for (final r in requests) {
      DateTime? reqDate;
      DateTime? procDate;
      try {
        if (r['requested_at'] != null) reqDate = DateTime.parse(r['requested_at']);
        if (r['processed_at'] != null) procDate = DateTime.parse(r['processed_at']);
      } catch (_) {}

      rows.add([
        r['id'] ?? '',
        r['full_name'] ?? 'Inconnu',
        r['email'] ?? '',
        r['user_id'] ?? 'Non lié',
        _getStatusLabel(r['status'] as String? ?? ''),
        reqDate != null ? df.format(reqDate) : '',
        procDate != null ? df.format(procDate) : '',
        r['processed_by'] ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = html.Blob([csvData], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(bytes);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'demandes_mot_de_passe_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      )
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${requests.length} demandes exportées en CSV'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(passwordResetRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/password-resets'),
          Expanded(
            child: Column(
              children: [
                _buildHeader(requestsAsync),
                _buildTabsBar(requestsAsync),
                if (_selectedIds.isNotEmpty) _buildMultiActionBar(),
                Expanded(
                  child: requestsAsync.when(
                    loading: () => const PasswordResetsSkeletonLoader(),
                    error: (e, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            UserFriendlyError.format(
                              e,
                              fallback: 'Unable to load password reset requests right now. Please try again.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(passwordResetRequestsProvider);
                              ref.invalidate(pendingPasswordResetCountProvider);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Réessayer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6D4CF6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    data: (requests) => _buildContent(requests),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<List<Map<String, dynamic>>> requestsAsync) {
    final allRequests = requestsAsync.value ?? [];
    final total = allRequests.length;
    final pending = allRequests.where((r) => r['status'] == 'pending').length;
    final approved = allRequests.where((r) => r['status'] == 'approved').length;
    final rejected = allRequests.where((r) => r['status'] == 'rejected').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title + Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mot de passe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$total demandes • $pending en attente • $approved approuvées • $rejected rejetées',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),

          // Debounced Search Input (250px)
          Container(
            width: 250,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un utilisateur...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Export CSV Button
          requestsAsync.maybeWhen(
            data: (list) => _buildHeaderIconButton(
              icon: Icons.download_rounded,
              tooltip: 'Exporter CSV',
              onPressed: () => _exportCsv(_filterRequests(list, _tabController.index)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),

          // Print Button
          _buildHeaderIconButton(
            icon: Icons.print_outlined,
            tooltip: 'Imprimer',
            onPressed: () => html.window.print(),
          ),
          const SizedBox(width: 8),

          // Refresh Button
          _buildHeaderIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(passwordResetRequestsProvider);
              ref.invalidate(pendingPasswordResetCountProvider);
            },
          ),
          const SizedBox(width: 16),

          // Primary Direct Reset Button
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _showDirectResetDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Réinitialiser un mot de passe',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: const Color(0xFF6D4CF6).withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      color: isActive ? const Color(0xFF655DD5) : AppColors.textTertiary,
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? const Color(0xFFF5F3FF) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive
                ? const Color(0xFF655DD5).withOpacity(0.2)
                : Colors.transparent,
          ),
        ),
      ),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUBPAGE TABS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabsBar(AsyncValue<List<Map<String, dynamic>>> requestsAsync) {
    final list = requestsAsync.value ?? [];
    final pendingCount = list.where((r) => r['status'] == 'pending').length;
    final approvedCount = list.where((r) => r['status'] == 'approved').length;
    final rejectedCount = list.where((r) => r['status'] == 'rejected').length;
    final allCount = list.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorColor: const Color(0xFF6D4CF6),
        indicatorWeight: 2.5,
        labelColor: const Color(0xFF6D4CF6),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          _buildTab('En attente', Icons.hourglass_empty_rounded, pendingCount, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
          _buildTab('Approuvées', Icons.check_circle_outline_rounded, approvedCount, const Color(0xFFECFDF5), const Color(0xFF059669)),
          _buildTab('Rejetées', Icons.cancel_outlined, rejectedCount, const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
          _buildTab('Toutes', Icons.format_list_bulleted_rounded, allCount, const Color(0xFFF1F5F9), const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Tab _buildTab(String label, IconData icon, int count, Color badgeBg, Color badgeFg) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MULTI-ACTION BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildMultiActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6D4CF6).withOpacity(0.08),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6D4CF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedIds.length} sélectionné${_selectedIds.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () {
              setState(() => _selectedIds.clear());
            },
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Désélectionner'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),

          // Batch Approve
          ElevatedButton.icon(
            onPressed: _confirmBatchApprove,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Approuver la sélection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Batch Reject
          ElevatedButton.icon(
            onPressed: _confirmBatchReject,
            icon: const Icon(Icons.highlight_off_rounded, size: 16),
            label: const Text('Rejeter la sélection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Batch Delete
          ElevatedButton.icon(
            onPressed: _confirmBatchDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTENT & DATA TABLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildContent(List<Map<String, dynamic>> requests) {
    final currentTabFiltered = _filterRequests(requests, _tabController.index);
    final pendingCount = requests.where((r) => r['status'] == 'pending').length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Quick Status Pill & Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$pendingCount demande${pendingCount > 1 ? 's' : ''} en attente de traitement',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Toutes les demandes sont traitées',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(
                  'Affichage de ${currentTabFiltered.length} demande${currentTabFiltered.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Main Table Card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: currentTabFiltered.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          _buildTableHeader(currentTabFiltered),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: ListView.separated(
                              itemCount: currentTabFiltered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final req = currentTabFiltered[index];
                                final reqId = req['id'] as String;
                                final isSelected = _selectedIds.contains(reqId);
                                return _buildTableRow(req, isSelected);
                              },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              size: 28,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune demande trouvée',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aucun résultat correspondant à votre recherche'
                : 'Aucune demande dans cette catégorie pour le moment',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(List<Map<String, dynamic>> items) {
    final allSelected = items.isNotEmpty && items.every((r) => _selectedIds.contains(r['id']));

    return Container(
      height: 44,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Master Checkbox
          SizedBox(
            width: 32,
            child: Checkbox(
              value: allSelected,
              activeColor: const Color(0xFF6D4CF6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.addAll(items.map((r) => r['id'] as String));
                  } else {
                    for (final r in items) {
                      _selectedIds.remove(r['id']);
                    }
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 12),

          // Utilisateur Header
          const Expanded(
            flex: 4,
            child: Text(
              'UTILISATEUR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Date de demande Header
          const Expanded(
            flex: 2,
            child: Text(
              'DATE DE DEMANDE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Traité le Header
          const Expanded(
            flex: 2,
            child: Text(
              'TRAITÉ LE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Statut Header
          const Expanded(
            flex: 2,
            child: Text(
              'STATUT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Actions Header
          const SizedBox(
            width: 48,
            child: Text(
              'ACTIONS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> request, bool isSelected) {
    final requestId = request['id'] as String;
    final fullName = request['full_name'] as String? ?? 'Inconnu';
    final email = request['email'] as String? ?? '';
    final status = (request['status'] as String? ?? 'pending').toLowerCase();
    final userId = request['user_id'] as String?;

    DateTime? requestedAt;
    DateTime? processedAt;
    try {
      if (request['requested_at'] != null) {
        requestedAt = DateTime.parse(request['requested_at']);
      }
      if (request['processed_at'] != null) {
        processedAt = DateTime.parse(request['processed_at']);
      }
    } catch (_) {}

    final df = DateFormat('dd/MM/yyyy HH:mm');

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(requestId);
          } else {
            _selectedIds.add(requestId);
          }
        });
      },
      hoverColor: const Color(0xFFF8FAFC),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: isSelected ? const Color(0xFF6D4CF6).withOpacity(0.04) : Colors.transparent,
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                activeColor: const Color(0xFF6D4CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(requestId);
                    } else {
                      _selectedIds.remove(requestId);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),

            // Utilisateur
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  UserAvatar(
                    name: fullName,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (userId != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Lié',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Date de demande
            Expanded(
              flex: 2,
              child: Text(
                requestedAt != null ? df.format(requestedAt) : '-',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Traité le
            Expanded(
              flex: 2,
              child: Text(
                processedAt != null ? df.format(processedAt) : '-',
                style: TextStyle(
                  fontSize: 12,
                  color: processedAt != null ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  fontWeight: processedAt != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),

            // Statut Badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(status),
              ),
            ),

            // Actions Menu
            SizedBox(
              width: 48,
              child: Center(
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Actions',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 8,
                  offset: const Offset(-140, 36),
                  onSelected: (action) => _handleRowAction(action, request),
                  itemBuilder: (ctx) => [
                    if (status == 'pending') ...[
                      _buildPopupItem(
                        'approve',
                        Icons.check_circle_outline_rounded,
                        'Approuver la demande',
                        const Color(0xFF059669),
                      ),
                      _buildPopupItem(
                        'reject',
                        Icons.highlight_off_rounded,
                        'Rejeter la demande',
                        const Color(0xFFDC2626),
                      ),
                      const PopupMenuDivider(),
                    ],
                    if (userId != null)
                      _buildPopupItem(
                        'profile',
                        Icons.person_outline_rounded,
                        'Voir le profil',
                        const Color(0xFF6D4CF6),
                      ),
                    _buildPopupItem(
                      'copy_email',
                      Icons.content_copy_rounded,
                      'Copier l\'email',
                      const Color(0xFF64748B),
                    ),
                    const PopupMenuDivider(),
                    _buildPopupItem(
                      'delete',
                      Icons.delete_outline_rounded,
                      'Supprimer',
                      AppColors.error,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        icon = Icons.check_circle_rounded;
        label = 'Approuvée';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        label = 'Rejetée';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        icon = Icons.hourglass_empty_rounded;
        label = 'En attente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: value == 'delete' ? AppColors.error : const Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRowAction(String action, Map<String, dynamic> request) {
    switch (action) {
      case 'approve':
        _showApproveDialog(request);
        break;
      case 'reject':
        _showRejectDialog(request);
        break;
      case 'profile':
        final userId = request['user_id'] as String?;
        if (userId != null) {
          context.push('/users/$userId');
        }
        break;
      case 'copy_email':
        final email = request['email'] as String? ?? '';
        Clipboard.setData(ClipboardData(text: email));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email copié dans le presse-papiers')),
        );
        break;
      case 'delete':
        _showDeleteDialog(request);
        break;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approuvée';
      case 'rejected':
        return 'Rejetée';
      default:
        return 'En attente';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MODALS & DIALOGS (WITH BACKGROUND BLUR)
  // ─────────────────────────────────────────────────────────────

  /// Approve Dialog: Generates password, displays copyable code, and updates Supabase
  Future<void> _showApproveDialog(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;
    final fullName = request['full_name'] as String? ?? 'l\'utilisateur';
    final email = request['email'] as String? ?? '';
    final userId = request['user_id'] as String?;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible: cette demande n\'est pas rattachée à un utilisateur existant'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final newPassword = ref.read(usersProvider.notifier).generatePassword();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Approuver la demande',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Un nouveau mot de passe va être généré pour $fullName ($email).',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),

              // Password container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded, size: 18, color: Color(0xFF6D4CF6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        newPassword,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copier',
                      color: const Color(0xFF64748B),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: newPassword));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Mot de passe copié !'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Warning box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Copiez ce mot de passe afin de le communiquer directement à l\'utilisateur.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Confirmer et réinitialiser',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await UserManagementService.resetPassword(userId, newPassword: newPassword);

      await supabase
          .from('password_reset_requests')
          .update({
            'status': 'approved',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': supabase.auth.currentUser?.id,
            'new_password_sent': true,
          })
          .eq('id', requestId);

      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);
      ref.invalidate(usersProvider);
      ref.invalidate(userProfileDataProvider(userId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe réinitialisé et demande approuvée'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Reject Dialog
  Future<void> _showRejectDialog(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.highlight_off_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rejeter la demande',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            'Voulez-vous vraiment rejeter cette demande de réinitialisation de mot de passe ?',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Rejeter', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('password_reset_requests')
          .update({
            'status': 'rejected',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': supabase.auth.currentUser?.id,
          })
          .eq('id', requestId);

      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande rejetée'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Delete Dialog
  Future<void> _showDeleteDialog(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Supprimer la demande ?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            'Cette demande sera définitivement retirée de l\'historique.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('password_reset_requests').delete().eq('id', requestId);

      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande supprimée de l\'historique'),
            backgroundColor: Color(0xFF6D4CF6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Batch Approve
  Future<void> _confirmBatchApprove() async {
    final pendingSelected = _selectedIds.toList();
    if (pendingSelected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Approuver les demandes sélectionnées ?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('Voulez-vous marquer comme approuvées les ${pendingSelected.length} demandes sélectionnées ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              child: const Text('Approuver', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('password_reset_requests')
          .update({
            'status': 'approved',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': supabase.auth.currentUser?.id,
          })
          .inFilter('id', pendingSelected);

      setState(() => _selectedIds.clear());
      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pendingSelected.length} demandes approuvées'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Batch Reject
  Future<void> _confirmBatchReject() async {
    final selected = _selectedIds.toList();
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rejeter les demandes sélectionnées ?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('Voulez-vous rejeter les ${selected.length} demandes sélectionnées ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('password_reset_requests')
          .update({
            'status': 'rejected',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': supabase.auth.currentUser?.id,
          })
          .inFilter('id', selected);

      setState(() => _selectedIds.clear());
      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} demandes rejetées'),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Batch Delete
  Future<void> _confirmBatchDelete() async {
    final selected = _selectedIds.toList();
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supprimer les demandes sélectionnées ?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('Voulez-vous supprimer définitivement les ${selected.length} demandes sélectionnées ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('password_reset_requests').delete().inFilter('id', selected);

      setState(() => _selectedIds.clear());
      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} demandes supprimées'),
            backgroundColor: const Color(0xFF6D4CF6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Direct Reset Password Dialog (Search user, generate password, copy)
  void _showDirectResetDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: const _DirectResetPasswordModal(),
      ),
    );
  }
}

/// Standalone modal for Direct Reset Password
class _DirectResetPasswordModal extends ConsumerStatefulWidget {
  const _DirectResetPasswordModal();

  @override
  ConsumerState<_DirectResetPasswordModal> createState() =>
      _DirectResetPasswordModalState();
}

class _DirectResetPasswordModalState
    extends ConsumerState<_DirectResetPasswordModal> {
  final TextEditingController _userSearchCtrl = TextEditingController();
  final TextEditingController _pwdCtrl = TextEditingController();
  UserModel? _selectedUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _regeneratePassword();
  }

  @override
  void dispose() {
    _userSearchCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _regeneratePassword() {
    final generated = ref.read(usersProvider.notifier).generatePassword();
    setState(() {
      _pwdCtrl.text = generated;
    });
  }

  Future<void> _submit() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un utilisateur')),
      );
      return;
    }

    if (_pwdCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit comporter au moins 6 caractères')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _selectedUser!;
      final newPwd = _pwdCtrl.text.trim();

      await UserManagementService.resetPassword(user.id, newPassword: newPwd);

      ref.invalidate(passwordResetRequestsProvider);
      ref.invalidate(pendingPasswordResetCountProvider);
      ref.invalidate(usersProvider);
      ref.invalidate(userProfileDataProvider(user.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mot de passe de ${user.fullName} réinitialisé avec succès'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final allUsers = usersState.value?.users ?? [];

    final searchLower = _userSearchCtrl.text.trim().toLowerCase();
    final matchingUsers = searchLower.isEmpty
        ? allUsers.take(10).toList()
        : allUsers.where((u) {
            final name = u.fullName.toLowerCase();
            final email = u.email.toLowerCase();
            final code = (u.studentCode ?? '').toLowerCase();
            return name.contains(searchLower) ||
                email.contains(searchLower) ||
                code.contains(searchLower);
          }).take(10).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D4CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xFF6D4CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Réinitialiser un mot de passe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Attribuer un nouveau mot de passe à un compte',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search User Field
              const Text(
                'UTILISATEUR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),

              if (_selectedUser != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6D4CF6)),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(name: _selectedUser!.fullName, radius: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedUser!.fullName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              _selectedUser!.email,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _selectedUser = null),
                        tooltip: 'Changer d\'utilisateur',
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _userSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, email ou matricule...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // User results list
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: matchingUsers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: Text(
                              'Aucun utilisateur correspondant',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: matchingUsers.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, idx) {
                            final u = matchingUsers[idx];
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedUser = u;
                                  _userSearchCtrl.clear();
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    UserAvatar(name: u.fullName, radius: 14),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u.fullName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            u.email,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        u.role.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],

              const SizedBox(height: 18),

              // Password field
              const Text(
                'NOUVEAU MOT DE PASSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pwdCtrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6D4CF6)),
                    tooltip: 'Générer un autre',
                    onPressed: _regeneratePassword,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CF6).withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      fixedSize: const Size(44, 44),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B)),
                    tooltip: 'Copier',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _pwdCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mot de passe copié !'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      fixedSize: const Size(44, 44),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action buttons (40px)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        _isLoading ? 'Mise à jour...' : 'Réinitialiser',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
}
