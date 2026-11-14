import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceItemModel {
  final int index;
  final String ref;
  final String designation;
  final int quantity;
  final double unitPriceHt;
  final double tvaPercent;

  InvoiceItemModel({
    required this.index,
    required this.ref,
    required this.designation,
    required this.quantity,
    required this.unitPriceHt,
    this.tvaPercent = 0.0,
  });

  double get totalHt => quantity * unitPriceHt;
  double get tvaAmount => totalHt * (tvaPercent / 100.0);
  double get totalTtc => totalHt + tvaAmount;

  Map<String, dynamic> toJson() => {
    'index': index,
    'ref': ref,
    'designation': designation,
    'quantity': quantity,
    'unit_price_ht': unitPriceHt,
    'tva_percent': tvaPercent,
    'total_ht': totalHt,
    'total_ttc': totalTtc,
  };

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      index: (json['index'] as num?)?.toInt() ?? 1,
      ref: (json['ref'] ?? 'P-0001').toString(),
      designation: (json['designation'] ?? 'Abonnement').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceHt: (json['unit_price_ht'] as num?)?.toDouble() ?? 0.0,
      tvaPercent: (json['tva_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InvoiceDataModel {
  final String invoiceNumber;
  final DateTime date;
  final String issuerName;
  final String issuerCountry;
  final String matriculeFiscale;
  final String clientName;
  final List<InvoiceItemModel> items;
  final double timbreFiscal;

  InvoiceDataModel({
    required this.invoiceNumber,
    required this.date,
    this.issuerName = 'Aziz Tounsi',
    this.issuerCountry = 'TN',
    this.matriculeFiscale = '2007778S',
    required this.clientName,
    required this.items,
    this.timbreFiscal = 1.0,
  });

  double get totalHt => items.fold(0.0, (acc, item) => acc + item.totalHt);
  double get totalTva => items.fold(0.0, (acc, item) => acc + item.tvaAmount);
  double get totalTtc => totalHt + totalTva;
  double get netToPay => totalTtc + timbreFiscal;

  String get amountInWords => FrenchNumberToWords.toLegalSentence(netToPay);
}

class FrenchNumberToWords {
  static const _units = [
    '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
    'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept',
    'dix-huit', 'dix-neuf'
  ];

  static const _tens = [
    '', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante-dix',
    'quatre-vingt', 'quatre-vingt-dix'
  ];

  static String convert(int n) {
    if (n == 0) return 'zéro';
    return _convertRecursive(n).trim();
  }

  static String _convertRecursive(int n) {
    if (n < 20) return _units[n];
    if (n < 70) {
      final rem = n % 10;
      final t = _tens[n ~/ 10];
      if (rem == 1) return '$t et un';
      if (rem > 0) return '$t-${_units[rem]}';
      return t;
    }
    if (n < 80) {
      final rem = n - 60;
      if (rem == 11) return 'soixante et onze';
      return 'soixante-${_convertRecursive(rem)}';
    }
    if (n < 100) {
      final rem = n - 80;
      final prefix = rem == 0 ? 'quatre-vingts' : 'quatre-vingt';
      if (rem > 0) return '$prefix-${_convertRecursive(rem)}';
      return prefix;
    }
    if (n < 1000) {
      final hundreds = n ~/ 100;
      final rem = n % 100;
      final hStr = hundreds == 1 ? 'cent' : '${_units[hundreds]} cent${rem == 0 ? "s" : ""}';
      if (rem > 0) return '$hStr ${_convertRecursive(rem)}';
      return hStr;
    }
    if (n < 1000000) {
      final thousands = n ~/ 1000;
      final rem = n % 1000;
      final tStr = thousands == 1 ? 'mille' : '${_convertRecursive(thousands)} mille';
      if (rem > 0) return '$tStr ${_convertRecursive(rem)}';
      return tStr;
    }
    final millions = n ~/ 1000000;
    final rem = n % 1000000;
    final mStr = millions == 1 ? 'un million' : '${_convertRecursive(millions)} millions';
    if (rem > 0) return '$mStr ${_convertRecursive(rem)}';
    return mStr;
  }

  static String toLegalSentence(double amount) {
    final dinars = amount.floor();
    final millimes = ((amount - dinars) * 1000).round();
    var words = convert(dinars);
    if (words.isNotEmpty) {
      words = words[0].toUpperCase() + words.substring(1);
    }
    var res = '$words Dinars';
    if (millimes > 0) {
      res += ' et ${convert(millimes)} Millimes';
    }
    return 'Arrêté(e) la/le présent(e) facture à la somme de $res';
  }
}

class InvoicePdfGenerator {
  static String formatTnd(double val) {
    final isNegative = val < 0;
    final absVal = val.abs();
    final integerPart = absVal.floor();
    final decimalPart = ((absVal - integerPart) * 1000).round().toString().padLeft(3, '0');

    final strInt = integerPart.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < strInt.length; i++) {
      if (i > 0 && (strInt.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(strInt[i]);
    }
    final sign = isNegative ? '-' : '';
    return '$sign${buffer.toString()},$decimalPart DT';
  }

  static Future<Uint8List> generatePdfBytes(InvoiceDataModel invoice) async {
    final pdf = pw.Document();

    final dateStr =
        '${invoice.date.day.toString().padLeft(2, '0')}/${invoice.date.month.toString().padLeft(2, '0')}/${invoice.date.year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER ROW ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Brand title (No left logo)
                  pw.Text(
                    invoice.issuerName.isNotEmpty ? invoice.issuerName : 'PythaOne SaaS',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#111827'),
                    ),
                  ),
                  // FACTURE title block
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'FACTURE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        invoice.invoiceNumber,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Date: $dateStr',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColor.fromHex('#4B5563'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 14),
              pw.Container(height: 1.2, color: PdfColor.fromHex('#D1D5DB')),
              pw.SizedBox(height: 12),

              // ── 2. ISSUER & CLIENT DETAILS ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        invoice.issuerName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        invoice.issuerCountry,
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'M/F: ${invoice.matriculeFiscale}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'CLIENT:',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#4B5563'),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        invoice.clientName,
                        style: pw.TextStyle(
                          fontSize: 13.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 22),

              // ── 3. MAIN TABLE ──
              pw.Table(
                border: null,
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),   // N°
                  1: const pw.FixedColumnWidth(60),   // Réf.
                  2: const pw.FlexColumnWidth(4),     // Désignation
                  3: const pw.FixedColumnWidth(55),   // Quantité
                  4: const pw.FixedColumnWidth(85),   // P.U HT
                  5: const pw.FixedColumnWidth(45),   // TVA
                  6: const pw.FixedColumnWidth(85),   // Total HT
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E5E7EB')),
                    children: [
                      _cell('N°', isHeader: true, align: pw.TextAlign.center),
                      _cell('Réf.', isHeader: true, align: pw.TextAlign.left),
                      _cell('Désignation', isHeader: true, align: pw.TextAlign.left),
                      _cell('Quantité', isHeader: true, align: pw.TextAlign.center),
                      _cell('P.U HT', isHeader: true, align: pw.TextAlign.right),
                      _cell('TVA', isHeader: true, align: pw.TextAlign.center),
                      _cell('Total HT', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Rows
                  ...invoice.items.map((item) {
                    return pw.TableRow(
                      children: [
                        _cell('${item.index}', align: pw.TextAlign.center),
                        _cell(item.ref, align: pw.TextAlign.left),
                        _cell(item.designation, isBold: true, align: pw.TextAlign.left),
                        _cell('${item.quantity}', align: pw.TextAlign.center),
                        _cell(formatTnd(item.unitPriceHt), align: pw.TextAlign.right),
                        _cell('${item.tvaPercent.toStringAsFixed(0)}%', align: pw.TextAlign.center),
                        _cell(formatTnd(item.totalHt), align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 24),

              // ── 4. SUMMARY BLOCK (TVA Breakdown on Left, Totals on Right) ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // TVA Breakdown Table
                  pw.Container(
                    width: 200,
                    child: pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1),
                        1: const pw.FlexColumnWidth(1.8),
                        2: const pw.FlexColumnWidth(1.5),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E5E7EB')),
                          children: [
                            _cell('TVA', isHeader: true, align: pw.TextAlign.center, padding: 4),
                            _cell('Base HT', isHeader: true, align: pw.TextAlign.center, padding: 4),
                            _cell('Montant', isHeader: true, align: pw.TextAlign.center, padding: 4),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            _cell('${invoice.items.isNotEmpty ? invoice.items.first.tvaPercent.toStringAsFixed(0) : "0"}%', align: pw.TextAlign.center, padding: 6),
                            _cell(formatTnd(invoice.totalHt), align: pw.TextAlign.center, padding: 6),
                            _cell(formatTnd(invoice.totalTva), align: pw.TextAlign.center, padding: 6),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Totals Summary Box
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _summaryRow('Total HT', formatTnd(invoice.totalHt)),
                        pw.SizedBox(height: 6),
                        _summaryRow('Total TTC', formatTnd(invoice.totalTtc)),
                        pw.SizedBox(height: 6),
                        _summaryRow('Timbre fiscal', formatTnd(invoice.timbreFiscal)),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#E5E7EB'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Net à payer',
                                style: pw.TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Text(
                                formatTnd(invoice.netToPay),
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 28),

              // ── 5. LEGAL NOTICE & SIGNATURE ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 8, right: 20),
                      child: pw.Text(
                        invoice.amountInWords,
                        style: pw.TextStyle(
                          fontStyle: pw.FontStyle.italic,
                          fontSize: 9.5,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 210,
                    height: 85,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#D1D5DB'), width: 1),
                    ),
                    alignment: pw.Alignment.bottomCenter,
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(
                      'Signature',
                      style: pw.TextStyle(
                        fontStyle: pw.FontStyle.italic,
                        fontSize: 9.5,
                        color: PdfColor.fromHex('#9CA3AF'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    double padding = 7.0,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: padding),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 9,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
          ),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  static Future<void> downloadOrPrintInvoice(InvoiceDataModel invoice) async {
    final bytes = await generatePdfBytes(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${invoice.invoiceNumber}.pdf',
    );
  }
}
