import 'dart:io';
import 'package:csv/csv.dart';
// import 'package:path_provider/path_provider.dart'; // Not directly needed if we use Printing for PDF or Share for CSV, but good for saving.
// Actually, for CSV on mobile, usually we share it or save to specialized directory.
// Let's use share_plus for sharing the CSV/PDF easily, or printing package handles PDF sharing/printing.
// For CSV, we might need path_provider to save temporary file to share.
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../models/ledger_transaction.dart';

class ExportService {
  /// Generate and share/print a PDF report
  Future<void> generatePdf(
    List<Transaction> transactions,
    String title,
    String currencySymbol,
  ) async {
    final pdf = pw.Document();

    // Sort transactions by date (newest first)
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Transaction Report',
                    style: pw.TextStyle(font: fontBold, fontSize: 24),
                  ),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              border: null,
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue600,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              headers: ['Date', 'Title', 'Category', 'Type', 'Amount'],
              data: transactions.map((tx) {
                return [
                  DateFormat('MMM dd, yyyy').format(tx.dateTime),
                  tx.title,
                  // We might not have category name easily here without passing it or mapping IDs.
                  // For now, let's just show "Transaction" if not mapped, or maybe pass category map?
                  // To keep it simple, we'll iterate. Ideally we should pass a list of DTOs with resolved names.
                  // But for now, let's just check if we can resolve it or leave it blank/ID.
                  // Actually, let's just use "Category" column and maybe generic if ID.
                  // BETTER: The caller should filter/map this before calling or we just show simple data.
                  // Let's assume the caller might want to pass mapped data, but `Transaction` model is what we have.
                  // We'll skip category name resolution inside here to avoid dependency on Provider/Context.
                  // We can display "Expense"/"Income" clearly.
                  // Note: In a real app, I'd pass a dedicated ExportModel.
                  tx.categoryId ?? '-',
                  tx.isExpense ? 'Expense' : 'Income',
                  '${tx.isExpense ? '-' : '+'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Balance: $currencySymbol${transactions.fold<double>(0, (sum, t) => sum + (t.isExpense ? -t.amount : t.amount)).toStringAsFixed(2)}',
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Transaction_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );
  }

  /// Generate and share a CSV file
  Future<void> generateCsv(
    List<Transaction> transactions,
    String title,
    String currencySymbol,
  ) async {
    // Sort transactions by date (newest first)
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Date',
      'Time',
      'Title',
      'Category ID',
      'Type',
      'Amount',
      'Payment Method',
    ]);

    // Data
    for (var tx in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(tx.dateTime),
        DateFormat('HH:mm').format(tx.dateTime),
        tx.title,
        tx.categoryId ?? '',
        tx.isExpense ? 'Expense' : 'Income',
        (tx.isExpense ? -tx.amount : tx.amount),
        tx.paymentMethod ?? '',
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/transactions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Transaction Report: $title');
  }

  /// Generate and share/print a PDF report for Ledger
  Future<void> generateLedgerPdf(
    List<LedgerTransaction> transactions,
    String title,
    String currencySymbol,
    String currentUserContact,
  ) async {
    final pdf = pw.Document();

    // Sort transactions by date (newest first)
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Ledger Report',
                    style: pw.TextStyle(font: fontBold, fontSize: 24),
                  ),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              border: null,
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue600,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              headers: ['Date', 'Description', 'Partner', 'Amount'],
              data: transactions.map((tx) {
                // Helper to check if sent
                bool arePhonesEqual(String? p1, String? p2) {
                  if (p1 == null || p2 == null) return false;
                  final n1 = p1.replaceAll(RegExp(r'\D'), '');
                  final n2 = p2.replaceAll(RegExp(r'\D'), '');
                  if (n1.isEmpty || n2.isEmpty) return false;
                  if (n1 == n2) return true;
                  final minLen = n1.length < n2.length ? n1.length : n2.length;
                  if (minLen >= 7) {
                    return n1.substring(n1.length - minLen) == n2.substring(n2.length - minLen);
                  }
                  return false;
                }

                final isSent = arePhonesEqual(
                  tx.senderPhone,
                  currentUserContact,
                );
                final otherName = isSent ? tx.receiverName : tx.senderName;

                return [
                  DateFormat('MMM dd, yyyy').format(tx.dateTime),
                  tx.description,
                  otherName,
                  '${isSent ? '-' : '+'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Net Balance: $currencySymbol${transactions.fold<double>(0, (sum, t) {
                    bool arePhonesEqual(String? p1, String? p2) {
                      if (p1 == null || p2 == null) return false;
                      final n1 = p1.replaceAll(RegExp(r'\D'), '');
                      final n2 = p2.replaceAll(RegExp(r'\D'), '');
                      if (n1.isEmpty || n2.isEmpty) return false;
                      if (n1 == n2) return true;
                      final minLen = n1.length < n2.length ? n1.length : n2.length;
                      if (minLen >= 7) {
                        return n1.substring(n1.length - minLen) == n2.substring(n2.length - minLen);
                      }
                      return false;
                    }

                    final isSent = arePhonesEqual(t.senderPhone, currentUserContact);
                    return sum + (isSent ? -t.amount : t.amount);
                  }).toStringAsFixed(2)}',
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Ledger_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );
  }

  /// Generate and share a CSV file for Ledger
  Future<void> generateLedgerCsv(
    List<LedgerTransaction> transactions,
    String title,
    String currencySymbol,
    String currentUserContact,
  ) async {
    // Sort transactions by date (newest first)
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Date',
      'Time',
      'Description',
      'Sender Name',
      'Sender Phone',
      'Receiver Name',
      'Receiver Phone',
      'Type',
      'Amount',
    ]);

    // Data
    for (var tx in transactions) {
      // Helper to check if sent
      bool arePhonesEqual(String? p1, String? p2) {
        if (p1 == null || p2 == null) return false;
        final n1 = p1.replaceAll(RegExp(r'\D'), '');
        final n2 = p2.replaceAll(RegExp(r'\D'), '');
        if (n1.isEmpty || n2.isEmpty) return false;
        if (n1 == n2) return true;
        final minLen = n1.length < n2.length ? n1.length : n2.length;
        if (minLen >= 7) {
          return n1.substring(n1.length - minLen) == n2.substring(n2.length - minLen);
        }
        return false;
      }

      final isSent = arePhonesEqual(tx.senderPhone, currentUserContact);

      rows.add([
        DateFormat('yyyy-MM-dd').format(tx.dateTime),
        DateFormat('HH:mm').format(tx.dateTime),
        tx.description,
        tx.senderName,
        tx.senderPhone,
        tx.receiverName,
        tx.receiverPhone ?? '',
        isSent ? 'Sent' : 'Received',
        (isSent ? -tx.amount : tx.amount),
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/ledger_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Ledger Report: $title');
  }

  /// Generate and share/print a PDF report for Investments
  Future<void> generateInvestmentPdf(
    List<dynamic> transactions, // InvestmentTransaction
    String title,
    String currencySymbol,
    Map<String, String> assetNames,
  ) async {
    final pdf = pw.Document();

    // Sort transactions by date (newest first)
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Investment Report',
                    style: pw.TextStyle(font: fontBold, fontSize: 24),
                  ),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              border: null,
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue600,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              headers: ['Date', 'Asset', 'Type', 'Qty', 'Price', 'Amount'],
              data: transactions.map((tx) {
                final isBuy = tx.type.toLowerCase() == 'buy';
                return [
                  DateFormat('MMM dd, yyyy').format(tx.dateTime),
                  assetNames[tx.investmentId] ?? 'Unknown Asset',
                  isBuy ? 'Buy' : 'Sell',
                  tx.quantity?.toStringAsFixed(2) ?? '-',
                  tx.pricePerUnit?.toStringAsFixed(2) ?? '-',
                  '${isBuy ? '+' : '-'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Net Invested: $currencySymbol${transactions.fold<double>(0, (sum, t) {
                    final isBuy = t.type.toLowerCase() == 'buy';
                    return sum + (isBuy ? t.amount : -t.amount);
                  }).toStringAsFixed(2)}',
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Investment_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );
  }

  /// Generate and share a CSV file for Investments
  Future<void> generateInvestmentCsv(
    List<dynamic> transactions, // InvestmentTransaction
    String title,
    String currencySymbol,
    Map<String, String> assetNames,
  ) async {
    // Sort transactions by date (newest first)
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Date',
      'Time',
      'Asset Name',
      'Type',
      'Quantity',
      'Price Per Unit',
      'Total Amount',
    ]);

    // Data
    for (var tx in transactions) {
      final isBuy = tx.type.toLowerCase() == 'buy';
      rows.add([
        DateFormat('yyyy-MM-dd').format(tx.dateTime),
        DateFormat('HH:mm').format(tx.dateTime),
        assetNames[tx.investmentId] ?? 'Unknown',
        isBuy ? 'Buy' : 'Sell',
        tx.quantity ?? 0,
        tx.pricePerUnit ?? 0,
        (isBuy ? tx.amount : -tx.amount),
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/investments_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Investment Report: $title');
  }
}
