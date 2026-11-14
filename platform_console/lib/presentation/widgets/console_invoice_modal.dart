import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/invoice_pdf_generator.dart';
import '../../core/theme/console_theme.dart';
import '../providers/platform_provider.dart';

void showConsoleInvoiceGeneratorModal({
  required BuildContext context,
  required WidgetRef ref,
  required List<Map<String, dynamic>> schools,
  String? preselectedSchoolId,
  VoidCallback? onSaved,
}) {
  if (schools.isEmpty) return;

  String selectedSchoolId = preselectedSchoolId ?? schools[0]['id'] as String;
  final designationCtrl = TextEditingController(text: 'Abonnement SaaS');
  final quantityCtrl = TextEditingController(text: '1');
  final unitPriceCtrl = TextEditingController(text: '850.000');
  final tvaRateCtrl = TextEditingController(text: '0');
  final timbreFiscalCtrl = TextEditingController(text: '1.000');
  final issuerNameCtrl = TextEditingController(text: 'PythaOne SaaS Technologies');
  final matriculeCtrl = TextEditingController(text: '2007778S/A/M/000');

  bool savingAndDownloading = false;

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: StatefulBuilder(
        builder: (sbContext, setSbState) {
          final currentSchool = schools.firstWhere(
            (s) => s['id'] == selectedSchoolId,
            orElse: () => schools[0],
          );
          final clientName = (currentSchool['name'] ?? 'Client').toString();

          final qty = int.tryParse(quantityCtrl.text.trim()) ?? 1;
          final pu = double.tryParse(unitPriceCtrl.text.trim().replaceAll(',', '.')) ?? 850.0;
          final tvaRate = double.tryParse(tvaRateCtrl.text.trim()) ?? 0.0;
          final timbre = double.tryParse(timbreFiscalCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;

          final totalHt = qty * pu;
          final tvaAmount = totalHt * (tvaRate / 100.0);
          final totalTtc = totalHt + tvaAmount;
          final netToPay = totalTtc + timbre;
          final legalSentence = FrenchNumberToWords.toLegalSentence(netToPay);

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: 680,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── HEADER (NO LEFT LOGO) ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Créer une Facture Officielle',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: ConsoleColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Génère une facture conforme avec timbre fiscal et arrêté légal en toutes lettres.',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: ConsoleColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // ── FORM BODY (NO SECTION TITLES / VERTICAL COLORED LINES) ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Client & Issuer Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Établissement Client *',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedSchoolId,
                                      borderRadius: BorderRadius.circular(10),
                                      isDense: true,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      ),
                                      items: schools.map((s) {
                                        return DropdownMenuItem<String>(
                                          value: s['id'] as String,
                                          child: Text(s['name'] as String? ?? 'École', overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setSbState(() => selectedSchoolId = val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Émetteur (Fournisseur) *',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: issuerNameCtrl,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Matricule Fiscale & Timbre
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Matricule Fiscale *',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: matriculeCtrl,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Timbre Fiscal (DT)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: timbreFiscalCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setSbState(() {}),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        suffixText: 'DT',
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Designation & Pricing Line
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Désignation de la prestation *',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: designationCtrl,
                                      onChanged: (_) => setSbState(() {}),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Qté',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: quantityCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (_) => setSbState(() {}),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('P.U HT (DT)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: unitPriceCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setSbState(() {}),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        suffixText: 'DT',
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Live Calculations Card
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total HT:', style: TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                    Text(InvoicePdfGenerator.formatTnd(totalHt),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ConsoleColors.textPrimary)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TVA (0%):', style: TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                    Text(InvoicePdfGenerator.formatTnd(tvaAmount),
                                        style: const TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Timbre fiscal:', style: TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                    Text(InvoicePdfGenerator.formatTnd(timbre),
                                        style: const TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net à payer:',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ConsoleColors.textPrimary)),
                                    Text(InvoicePdfGenerator.formatTnd(netToPay),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF6D4CF6))),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    legalSentence,
                                    style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── FOOTER ACTIONS ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 40,
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B7280)),
                            child: const Text('Fermer', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Preview / Print PDF
                        SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final autoNumber = 'FAC-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
                              final invoiceData = InvoiceDataModel(
                                invoiceNumber: autoNumber,
                                date: DateTime.now(),
                                issuerName: issuerNameCtrl.text.trim(),
                                matriculeFiscale: matriculeCtrl.text.trim(),
                                clientName: clientName,
                                timbreFiscal: timbre,
                                items: [
                                  InvoiceItemModel(
                                    index: 1,
                                    ref: 'P-0001',
                                    designation: designationCtrl.text.trim(),
                                    quantity: qty,
                                    unitPriceHt: pu,
                                    tvaPercent: tvaRate,
                                  ),
                                ],
                              );
                              await InvoicePdfGenerator.downloadOrPrintInvoice(invoiceData);
                            },
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: const Text('Aperçu PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6D4CF6),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Save to Database and Download PDF
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: savingAndDownloading
                                ? null
                                : () async {
                                    setSbState(() => savingAndDownloading = true);

                                    // Auto-generate fresh unique invoice number each time
                                    final now = DateTime.now();
                                    final uniqueNumber = 'FAC-${now.year}-${(now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
                                    final due = now.add(const Duration(days: 30));

                                    final item = InvoiceItemModel(
                                      index: 1,
                                      ref: 'P-0001',
                                      designation: designationCtrl.text.trim(),
                                      quantity: qty,
                                      unitPriceHt: pu,
                                      tvaPercent: tvaRate,
                                    );

                                    final invoiceData = InvoiceDataModel(
                                      invoiceNumber: uniqueNumber,
                                      date: now,
                                      issuerName: issuerNameCtrl.text.trim(),
                                      matriculeFiscale: matriculeCtrl.text.trim(),
                                      clientName: clientName,
                                      timbreFiscal: timbre,
                                      items: [item],
                                    );

                                    final inserted = await ref.read(platformProvider.notifier).createDetailedInvoice(
                                      schoolId: selectedSchoolId,
                                      invoiceNumber: uniqueNumber,
                                      issueDate: DateFormat('yyyy-MM-dd').format(now),
                                      dueDate: DateFormat('yyyy-MM-dd').format(due),
                                      clientName: clientName,
                                      issuerName: issuerNameCtrl.text.trim(),
                                      issuerCountry: 'Tunisie',
                                      matriculeFiscale: matriculeCtrl.text.trim(),
                                      items: [item.toJson()],
                                      totalHt: totalHt,
                                      tvaRate: tvaRate,
                                      tvaAmount: tvaAmount,
                                      timbreFiscal: timbre,
                                      totalTtc: totalTtc,
                                      netToPay: netToPay,
                                      amountInWords: legalSentence,
                                    );

                                    setSbState(() => savingAndDownloading = false);

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }

                                    if (inserted != null) {
                                      onSaved?.call();
                                      try {
                                        await InvoicePdfGenerator.downloadOrPrintInvoice(invoiceData);
                                      } catch (_) {}

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Facture $uniqueNumber enregistrée avec succès !'),
                                            backgroundColor: ConsoleColors.success,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Erreur lors de l\'enregistrement de la facture.'),
                                            backgroundColor: ConsoleColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: savingAndDownloading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Enregistrer & PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6D4CF6),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
