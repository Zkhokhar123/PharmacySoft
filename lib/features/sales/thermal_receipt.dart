import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/formatters.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/sale.dart';

/// Generates and sends a 80mm or 58mm thermal receipt slip to the printer.
class ThermalReceipt {
  ThermalReceipt._();

  static Future<void> printReceipt(
    Sale sale,
    AppSettings settings, {
    bool is58mm = false,
  }) async {
    final doc = pw.Document();
    final sym = settings.currencySymbol;
    final pageFormat = is58mm ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    final double baseFontSize = is58mm ? 7.5 : 8.5;
    final double headerFontSize = is58mm ? 13.0 : 15.0;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Pharmacy Header
              pw.Text(
                settings.pharmacyName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              if (settings.address.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  settings.address,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: baseFontSize - 1),
                ),
              ],
              if (settings.phone.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  'Tel: ${settings.phone}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: baseFontSize - 1),
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),

              // Invoice & Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Inv: ${sale.invoiceNumber}',
                      style: pw.TextStyle(
                          fontSize: baseFontSize,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(Formatters.dateTime(sale.dateTimeValue),
                      style: pw.TextStyle(fontSize: baseFontSize - 1.5)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer: ${sale.customerName}',
                      style: pw.TextStyle(fontSize: baseFontSize)),
                  pw.Text('Pay: ${sale.paymentMethod}',
                      style: pw.TextStyle(
                          fontSize: baseFontSize - 1,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),

              if (sale.isReturned) ...[
                pw.SizedBox(height: 3),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  color: PdfColors.red100,
                  child: pw.Text(
                    '** RETURNED / REFUNDED **',
                    style: pw.TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900,
                    ),
                  ),
                ),
              ],

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),

              // Table Headers
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontSize: baseFontSize,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: baseFontSize,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Price',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: baseFontSize,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: baseFontSize,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List
              ...sale.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.medicineName,
                                style: pw.TextStyle(fontSize: baseFontSize)),
                            if (item.batchNumber.isNotEmpty)
                              pw.Text('B:${item.batchNumber}',
                                  style: pw.TextStyle(
                                      fontSize: baseFontSize - 2,
                                      color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: baseFontSize)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                            item.unitPrice.toStringAsFixed(0),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: baseFontSize)),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                            item.lineTotal.toStringAsFixed(0),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: baseFontSize,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.8),

              // Totals
              _row('Subtotal:', Formatters.currency(sale.subtotal, symbol: sym),
                  baseFontSize),
              if (sale.discount > 0)
                _row(
                    'Discount:',
                    '- ${Formatters.currency(sale.discount, symbol: sym)}',
                    baseFontSize),
              if (sale.taxAmount > 0)
                _row('Tax:', Formatters.currency(sale.taxAmount, symbol: sym),
                    baseFontSize),

              pw.Divider(thickness: 1),

              _row('TOTAL:', Formatters.currency(sale.total, symbol: sym),
                  baseFontSize + 2,
                  bold: true),

              _row('Paid (${sale.paymentMethod}):',
                  Formatters.currency(sale.paid, symbol: sym), baseFontSize),

              if (sale.balance > 0.005)
                _row('Balance Due:',
                    Formatters.currency(sale.balance, symbol: sym), baseFontSize,
                    bold: true)
              else if (sale.balance < -0.005)
                _row(
                    'Change Return:',
                    Formatters.currency(sale.balance.abs(), symbol: sym),
                    baseFontSize,
                    bold: true),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Barcode
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: sale.invoiceNumber,
                  width: is58mm ? 120 : 150,
                  height: 30,
                  drawText: false,
                ),
              ),
              pw.SizedBox(height: 4),

              pw.Text(
                'Get Well Soon! Thank You!',
                style: pw.TextStyle(
                    fontSize: baseFontSize - 1,
                    fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Medicines returnable with bill within 3 days.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: baseFontSize - 2.5,
                    color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Receipt-${sale.invoiceNumber}',
      format: pageFormat,
      onLayout: (_) async => doc.save(),
    );
  }

  static pw.Widget _row(String label, String value, double fontSize,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
