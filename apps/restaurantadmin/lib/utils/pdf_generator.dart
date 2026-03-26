import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:restaurantadmin/models/daily_summary_data.dart';

class PdfGenerator {
  final DateFormat _dateFormatter = DateFormat('EEEE, MMMM d, yyyy');
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'de_DE',
    symbol: '€',
  ); // Example: German Euro

  Future<Uint8List> _generatePdfBytes(DailySummaryData summaryData) async {
    final pdf = pw.Document();

    // Consider adding a logo if you have one in assets
    // final logo = pw.MemoryImage(
    //   (await rootBundle.load('assets/your_logo.png')).buffer.asUint8List(),
    // );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(context, summaryData),
            pw.SizedBox(height: 20),
            _buildOverallTotals(context, summaryData),
            pw.SizedBox(height: 20),
            _buildOrderTypeSummaryTable(context, summaryData),
            pw.SizedBox(height: 30),
            _buildFooter(context),
          ];
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildHeader(pw.Context context, DailySummaryData summaryData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Daily Sales Summary',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          _dateFormatter.format(summaryData.date),
          style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700),
        ),
        pw.Divider(height: 20, thickness: 1.5),
      ],
    );
  }

  pw.Widget _buildOverallTotals(
    pw.Context context,
    DailySummaryData summaryData,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Overall Summary:',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildTotalRow('Total Orders:', summaryData.totalOrders.toString()),
        _buildTotalRow(
          'Total Revenue:',
          _currencyFormatter.format(summaryData.totalRevenue),
        ),
        _buildTotalRow(
          'Total Material Cost:',
          _currencyFormatter.format(summaryData.totalMaterialCost),
        ),
        _buildTotalRow(
          'Total Commissions Paid:',
          _currencyFormatter.format(summaryData.totalCommissionsPaid),
        ),
        _buildTotalRow(
          'Net Profit:',
          _currencyFormatter.format(summaryData.totalProfit),
          isBold: true,
          color: summaryData.totalProfit >= 0
              ? PdfColors.green700
              : PdfColors.red700,
        ),
      ],
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOrderTypeSummaryTable(
    pw.Context context,
    DailySummaryData summaryData,
  ) {
    final headers = [
      'Order Type',
      'Count',
      'Revenue',
      'Commissions',
      'Material Cost',
      'Profit',
    ];

    final data = summaryData.orderTypeSummaries.map((summary) {
      return [
        summary.typeName,
        summary.orderCount.toString(),
        _currencyFormatter.format(summary.totalRevenueForType),
        _currencyFormatter.format(summary.totalCommissionForType),
        _currencyFormatter.format(summary.totalMaterialCostForType),
        _currencyFormatter.format(summary.totalProfitForType),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Breakdown by Order Type:',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerRight,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
          }, // Align first column left
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          rowDecoration: const pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
          ),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }

  Future<void> generateAndShowDailySummaryPdf(
    DailySummaryData summaryData,
    String documentName,
  ) async {
    try {
      final pdfBytes = await _generatePdfBytes(summaryData);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: documentName, // e.g., 'Daily_Summary_2023-10-26.pdf'
      );
    } catch (e) {
      print('Error generating or showing PDF: $e');
      // Consider showing a user-facing error message via a SnackBar or Dialog in the calling widget
      throw Exception('Failed to generate or show PDF: $e');
    }
  }
}
