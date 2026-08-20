import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../data/services/core_data_service.dart';
import '../../providers/student_context_provider.dart';
import '../../widgets/semester_navigator.dart';
import '../../widgets/ios_loader.dart';

// Semester state provider for this screen
final soldeSemesterProvider = StateProvider<int>((ref) => 1);

// Payment categories for Tunisia
enum PaymentCategory {
  scolarite('Scolarité', Icons.school_rounded, Color(0xFF6366F1)),
  transport('Transport/Bus', Icons.directions_bus_rounded, Color(0xFFF59E0B)),
  inscription('Inscription', Icons.app_registration_rounded, Color(0xFF10B981)),
  uniforme('Uniforme', Icons.checkroom_rounded, Color(0xFFEC4899)),
  cantine('Cantine', Icons.restaurant_rounded, Color(0xFF8B5CF6)),
  activites('Activités', Icons.sports_soccer_rounded, Color(0xFF06B6D4)),
  autres('Autres', Icons.more_horiz_rounded, Color(0xFF64748B));

  final String label;
  final IconData icon;
  final Color color;
  const PaymentCategory(this.label, this.icon, this.color);
}

// Payment breakdown by category
class PaymentCategoryData {
  final PaymentCategory category;
  final double amount;
  final double paid;

  PaymentCategoryData({
    required this.category,
    required this.amount,
    required this.paid,
  });

  double get remaining => amount - paid;
  double get progressPercent => amount > 0 ? (paid / amount) * 100 : 0;
}

// Payment categories breakdown provider - always returns all 7 categories
final paymentCategoriesProvider = Provider<List<PaymentCategoryData>>((ref) {
  final plansAsync = ref.watch(paymentsDataProvider);
  final plans = plansAsync.asData?.value ?? [];
  final pricingAsync = ref.watch(pricingFallbackProvider);
  final pricing = pricingAsync.asData?.value ?? {};

  final Map<PaymentCategory, double> amounts = {};
  final Map<PaymentCategory, double> paid = {};

  for (final plan in plans) {
    final category = _mapCategory(plan.category);
    amounts[category] = (amounts[category] ?? 0) + plan.amountTotal;
    paid[category] = (paid[category] ?? 0) + plan.totalPaid;
  }

  // Fill in pricing fallback for categories with 0 amount
  for (final entry in pricing.entries) {
    final cat = _mapCategory(entry.key);
    if ((amounts[cat] ?? 0) == 0 && entry.value > 0) {
      amounts[cat] = entry.value;
    }
  }

  // Always return all 7 categories
  return PaymentCategory.values.map((cat) {
    return PaymentCategoryData(
      category: cat,
      amount: amounts[cat] ?? 0,
      paid: paid[cat] ?? 0,
    );
  }).toList();
});

// Semester count provider - fetches from system
final semesterCountProvider = FutureProvider<int>((ref) async {
  try {
    final context = await ref.watch(studentContextProvider.future);
    if (context == null) return 3;
    final supabase = Supabase.instance.client;
    final resp = await supabase
        .from('semesters')
        .select('id')
        .eq('academic_year_id', context.academicYearId ?? '')
        .order('number');
    if (resp.length > 0) return resp.length;
    // Fallback: count all semesters for school's current year
    final count = await supabase.rpc(
      'get_current_academic_year_semester_count',
      params: {'p_school_id': context.schoolId},
    );
    return (count as num?)?.toInt() ?? 3;
  } catch (e) {
    return 3;
  }
});

// Academic year date range provider
final academicYearDatesProvider = FutureProvider<({DateTime? start, DateTime? end})>((ref) async {
  try {
    final context = await ref.watch(studentContextProvider.future);
    if (context == null) return (start: null, end: null);
    final supabase = Supabase.instance.client;
    final resp = await supabase
        .from('academic_years')
        .select('start_date, end_date')
        .eq('id', context.academicYearId ?? '')
        .maybeSingle();
    if (resp == null) return (start: null, end: null);
    return (
      start: DateTime.tryParse(resp['start_date']?.toString() ?? ''),
      end: DateTime.tryParse(resp['end_date']?.toString() ?? ''),
    );
  } catch (e) {
    return (start: null, end: null);
  }
});

// Pricing fallback provider - fetches pricing from payment_pricing for all categories
final pricingFallbackProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    final context = await ref.watch(studentContextProvider.future);
    if (context == null || context.niveauId == null) return {};
    final supabase = Supabase.instance.client;

    final categories = ['scolarite', 'transport', 'inscription', 'uniforme', 'cantine', 'activites', 'autres'];
    final Map<String, double> pricing = {};

    for (final cat in categories) {
      try {
        final result = await supabase.rpc(
          'get_payment_pricing_for_enrollment',
          params: {
            'p_enrollment_id': context.enrollmentId ?? '',
            'p_category': cat,
          },
        );
        if (result != null && (result as List).isNotEmpty) {
          final amount = (result.first['amount'] as num?)?.toDouble();
          if (amount != null && amount > 0) {
            pricing[cat] = amount;
          }
        }
      } catch (_) {}
    }
    return pricing;
  } catch (e) {
    return {};
  }
});

PaymentCategory _mapCategory(String? category) {
  switch (category) {
    case 'scolarite':
      return PaymentCategory.scolarite;
    case 'transport':
      return PaymentCategory.transport;
    case 'inscription':
      return PaymentCategory.inscription;
    case 'uniforme':
      return PaymentCategory.uniforme;
    case 'cantine':
      return PaymentCategory.cantine;
    case 'activites':
      return PaymentCategory.activites;
    default:
      return PaymentCategory.autres;
  }
}

class MonSoldeScreen extends ConsumerStatefulWidget {
  const MonSoldeScreen({super.key});

  @override
  ConsumerState<MonSoldeScreen> createState() => _MonSoldeScreenState();
}

class _MonSoldeScreenState extends ConsumerState<MonSoldeScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paymentDataAsync = ref.watch(paymentsDataProvider);
    final categories = ref.watch(paymentCategoriesProvider);
    final selectedSemester = ref.watch(soldeSemesterProvider);
    final semesterCount = ref.watch(semesterCountProvider);
    final yearDates = ref.watch(academicYearDatesProvider);
    final pricingAsync = ref.watch(pricingFallbackProvider);

    return Material(
      type: MaterialType.transparency,
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
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: _buildHeader(l10n),
                ),
              ),

              // Semester Navigator
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DynamicSemesterNav(
                    selectedSemesterNumber: selectedSemester,
                    onChanged: (v) => ref.read(soldeSemesterProvider.notifier).state = v,
                    accentColor: const Color(0xFFF59E0B),
                    secondaryColor: const Color(0xFFF97316),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              // Content
              paymentDataAsync.when(
                data: (plans) => _buildContent(
                  context,
                  plans,
                  categories,
                  l10n,
                  semesterCount.asData?.value ?? 3,
                  yearDates.asData?.value,
                  pricingAsync.asData?.value ?? {},
                ),
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: IosLoader(color: Color(0xFFF59E0B)),
                  ),
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text('Erreur: $error'),
                      ],
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

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.payment_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.monSolde,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Suivi des paiements',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<PaymentPlanInfo> plans,
    List<PaymentCategoryData> categories,
    AppLocalizations l10n,
    int semesterCount,
    ({DateTime? start, DateTime? end})? yearDates,
    Map<String, double> pricing,
  ) {
    // Balance card uses ALL categories
    final allPlansTotal = plans.fold<double>(0, (sum, p) => sum + p.amountTotal);
    final allPaidAmount = plans.fold<double>(0, (sum, p) => sum + p.totalPaid);
    final pricingTotal = pricing.values.fold<double>(0, (sum, v) => sum + v);
    final totalAmount = allPlansTotal > 0 ? allPlansTotal : pricingTotal;
    final paidAmount = allPaidAmount;
    final remainingAmount = totalAmount - paidAmount;
    final progressPercent = totalAmount > 0 ? (paidAmount / totalAmount) * 100 : 0.0;

    // Schedule uses scolarite only
    final scolaritePlans = plans.where((p) => 
      p.category == null || p.category == 'scolarite'
    ).toList();
    final scolaritePricing = pricing['scolarite'] ?? 0.0;
    final scheduleTotal = scolaritePlans.fold<double>(0, (sum, p) => sum + p.amountTotal);
    final scheduleAmount = scheduleTotal > 0 ? scheduleTotal : scolaritePricing;

    // Flatten all scolarite payments across plans, sorted by due date
    final allPayments = scolaritePlans.expand((p) => p.payments).toList()
      ..sort((a, b) {
        final aDate = a.dueDate ?? DateTime(2100);
        final bDate = b.dueDate ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });

    // If no real payments, create placeholder schedule based on semester count
    final displayPayments = allPayments.isNotEmpty
        ? allPayments
        : _buildPlaceholderPayments(semesterCount, yearDates, scheduleAmount);

    // Categories excluding scolarite
    final nonScolariteCategories = categories.where((c) => 
      c.category != PaymentCategory.scolarite
    ).toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Main Balance Card
          _buildBalanceCard(
            remainingAmount,
            paidAmount,
            totalAmount,
            progressPercent,
          ),
          const SizedBox(height: 28),

          // Payment Schedule Section
          Text(
            l10n.paymentSchedule,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),

          ...displayPayments.map(
            (payment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GlassyPaymentCard(payment: payment, currency: 'TND'),
            ),
          ),
          const SizedBox(height: 28),

          // Categories Section Title
          Text(
            'Répartition par catégorie',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),

          // Categories excluding scolarite
          ...nonScolariteCategories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GlassyCategoryCard(category: cat),
            ),
          ),
        ]),
      ),
    );
  }

  List<PaymentInfo> _buildPlaceholderPayments(
    int semesterCount,
    ({DateTime? start, DateTime? end})? yearDates,
    double totalAmount,
  ) {
    if (semesterCount <= 0) semesterCount = 3;
    final startDate = yearDates?.start ?? DateTime(DateTime.now().year, 9, 1);
    final endDate = yearDates?.end ?? DateTime(DateTime.now().year + 6, 1);
    final totalMonths = (endDate.year - startDate.year) * 12 + (endDate.month - startDate.month);
    final monthsPerPart = (totalMonths / semesterCount).ceil();
    final partAmount = totalAmount > 0 ? totalAmount / semesterCount : 0.0;

    final payments = <PaymentInfo>[];
    for (int i = 0; i < semesterCount; i++) {
      final dueDate = DateTime(startDate.year, startDate.month + (i * monthsPerPart), 1);
      payments.add(PaymentInfo(
        id: 'placeholder_$i',
        amount: partAmount,
        dueDate: dueDate,
        status: 'pending',
      ));
    }
    return payments;
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    double remaining,
    double paid,
    double total,
    double progressPercent,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solde restant',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4, left: 6),
                  child: Text(
                    'TND',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payé: ${_formatCurrency(paid)} TND',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Total: ${_formatCurrency(total)} TND',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return formatter.format(amount);
  }
}

// Glassy Category Card
class _GlassyCategoryCard extends StatelessWidget {
  final PaymentCategoryData category;

  const _GlassyCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final cat = category.category;
    final isPaid = category.remaining <= 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: cat.color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(cat.icon, color: cat.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Payé',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar with gradient
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: (category.progressPercent / 100).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    cat.color,
                                    cat.color.withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: cat.color.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatCurrency(category.paid)} / ${_formatCurrency(category.amount)} TND',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (!isPaid)
                          Text(
                            'Reste: ${_formatCurrency(category.remaining)} TND',
                            style: TextStyle(
                              fontSize: 11,
                              color: cat.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return formatter.format(amount);
  }
}

// Glassy Payment Card
class _GlassyPaymentCard extends StatelessWidget {
  final PaymentInfo payment;
  final String currency;

  const _GlassyPaymentCard({required this.payment, required this.currency});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isPaid = payment.status == 'paid';
    final isOverdue =
        !isPaid &&
        payment.dueDate != null &&
        payment.dueDate!.isBefore(DateTime.now());

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isPaid) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Payé';
    } else if (isOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.warning_rounded;
      statusText = 'En retard';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.schedule_rounded;
      statusText = 'En attente';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPaymentDetails(context, payment, currency, dateFormat),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Échéance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (payment.dueDate != null)
                    Text(
                      dateFormat.format(payment.dueDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_formatCurrency(payment.amount)} $currency',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetails(
    BuildContext context,
    PaymentInfo payment,
    String currency,
    DateFormat dateFormat,
  ) {
    final isPaid = payment.status == 'paid';
    final isOverdue =
        !isPaid &&
        payment.dueDate != null &&
        payment.dueDate!.isBefore(DateTime.now());

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isPaid) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Payé';
    } else if (isOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.warning_rounded;
      statusText = 'En retard';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.schedule_rounded;
      statusText = 'En attente';
    }

    // Calculate delay duration for overdue payments
    String? delayText;
    if (isOverdue && payment.dueDate != null) {
      final delay = DateTime.now().difference(payment.dueDate!);
      final days = delay.inDays;
      if (days > 0) {
        delayText = '$days jour${days > 1 ? 's' : ''} de retard';
      }
    }

    // Generate reference if not exists
    final reference = payment.reference ?? 'PAY-${payment.id.length >= 8 ? payment.id.substring(0, 8).toUpperCase() : payment.id.toUpperCase()}';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header with status icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Détails du paiement',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Show delay duration for overdue as info row
              if (delayText != null) ...[
                const SizedBox(height: 24),
                _buildDetailRow(
                  'Retard',
                  delayText,
                  Icons.timer_off_rounded,
                  statusColor,
                ),
              ],
              if (delayText == null) const SizedBox(height: 24),
              // Amount
              _buildDetailRow(
                'Montant',
                '${_formatCurrency(payment.amount)} $currency',
                Icons.attach_money_rounded,
                statusColor,
              ),
              // Due date
              if (payment.dueDate != null)
                _buildDetailRow(
                  'Date d\'échéance',
                  dateFormat.format(payment.dueDate!),
                  Icons.calendar_today_rounded,
                  statusColor,
                ),
              // Paid date
              if (payment.paidAt != null)
                _buildDetailRow(
                  'Date de paiement',
                  dateFormat.format(payment.paidAt!),
                  Icons.event_available_rounded,
                  statusColor,
                ),
              // Payment method
              if (payment.method != null)
                _buildDetailRow(
                  'Méthode',
                  payment.displayMethod,
                  Icons.payment_rounded,
                  statusColor,
                ),
              // Reference
              _buildDetailRow(
                'Référence',
                reference,
                Icons.receipt_rounded,
                statusColor,
              ),
              // Notes
              if (payment.notes != null && payment.notes!.isNotEmpty)
                _buildDetailRow(
                  'Notes',
                  payment.notes!,
                  Icons.note_rounded,
                  statusColor,
                ),
              const SizedBox(height: 28),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * animation.value,
            sigmaY: 8 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return formatter.format(amount);
  }
}
