import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class InvoiceGenerator {
  static Future<File> generateInvoice(Map<String, dynamic> orderDetails) async {
    final pdf = pw.Document();
    final status = orderDetails['status'] as String? ?? 'Processing';

    // Create PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(orderDetails),
            pw.SizedBox(height: 20),
            _buildInvoiceInfo(orderDetails),
            pw.SizedBox(height: 20),
            _buildBillingInfo(orderDetails),
            pw.SizedBox(height: 20),
            _buildItemsTable(orderDetails),
            pw.SizedBox(height: 20),
            _buildTotalAmount(orderDetails),
            pw.SizedBox(height: 40),
            _buildFooter(status),
            if (status == 'Cancelled')
              _buildCancellationWatermark(),
          ];
        },
      ),
    );

    // Save the PDF file
    final output = await getTemporaryDirectory();
    final fileName = 'invoice_${orderDetails['orderId']}_${status.toLowerCase()}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildHeader(Map<String, dynamic> orderDetails) {
    final status = orderDetails['status'] as String? ?? 'Processing';
    final headerColor = _getStatusColor(status);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 40,
                    fontWeight: pw.FontWeight.bold,
                    color: headerColor,
                  ),
                ),
                pw.Text(
                  'Invoice #: ${orderDetails['orderId']}',
                  style: const pw.TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'WasteWisePro',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Mumbai, Maharashtra',
                  style: const pw.TextStyle(
                    fontSize: 14,
                  ),
                ),
                pw.Text(
                  'India',
                  style: const pw.TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(color: headerColor),
      ],
    );
  }

  static pw.Widget _buildInvoiceInfo(Map<String, dynamic> orderDetails) {
    final orderDate = DateTime.parse(orderDetails['orderDate']);
    final formattedDate = DateFormat('dd MMM yyyy').format(orderDate);
    final status = orderDetails['status'] as String? ?? 'Processing';
    final statusColor = _getStatusColor(status);

    String statusDetails = status;
    if (status == 'Cancelled' && orderDetails.containsKey('cancelledAt')) {
      final cancelledDate = DateTime.parse(orderDetails['cancelledAt']);
      final formattedCancelDate = DateFormat('dd MMM yyyy HH:mm').format(cancelledDate);
      statusDetails = '$status on $formattedCancelDate';
    } else if (status == 'Delivered' && orderDetails.containsKey('deliveredAt')) {
      final deliveredDate = DateTime.parse(orderDetails['deliveredAt']);
      final formattedDeliveryDate = DateFormat('dd MMM yyyy').format(deliveredDate);
      statusDetails = '$status on $formattedDeliveryDate';
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Date: $formattedDate',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'Order Status: $statusDetails',
              style: pw.TextStyle(
                fontSize: 14,
                color: statusColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Payment Method:',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              orderDetails['paymentMethod'],
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildBillingInfo(Map<String, dynamic> orderDetails) {
    final address = orderDetails['shippingAddress'] as Map<String, dynamic>;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Bill To:',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(address['name'] ?? 'N/A'),
          pw.Text('${address['house'] ?? ''}, ${address['road'] ?? ''}'),
          pw.Text('${address['city'] ?? 'N/A'}, ${address['state'] ?? 'N/A'}'),
          pw.Text('PIN: ${address['pincode'] ?? 'N/A'}'),
          pw.Text('Phone: ${address['phone'] ?? 'N/A'}'),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(Map<String, dynamic> orderDetails) {
    final items = orderDetails['items'] as List<dynamic>;

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            _buildTableCell('Item Description', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell('Unit Price', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
          ],
        ),
        // Table Items
        ...items.map((item) {
          final quantity = item['quantity'] as int? ?? 1;
          final price = item['price'] as num? ?? 0.0;
          final total = quantity * price;

          return pw.TableRow(
            children: [
              _buildTableCell(item['title'] ?? 'N/A'),
              _buildTableCell(quantity.toString()),
              _buildTableCell('Rs. ${price.toStringAsFixed(2)}'),
              _buildTableCell('Rs. ${total.toStringAsFixed(2)}'),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  static pw.Widget _buildTotalAmount(Map<String, dynamic> orderDetails) {
    final subtotal = orderDetails['totalAmount'] as num? ?? 0.0;
    final cgst = subtotal * 0.09;
    final sgst = subtotal * 0.09;
    final total = subtotal + cgst + sgst;

    return pw.Column(
      children: [
        _buildAmountRow('Subtotal:', subtotal),
        _buildAmountRow('CGST (9%):', cgst),
        _buildAmountRow('SGST (9%):', sgst),
        pw.Divider(),
        _buildAmountRow('Total Amount:', total, isTotal: true),
      ],
    );
  }

  static pw.Widget _buildAmountRow(String label, num amount,
      {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(String status) {
    String footerText = 'Thank you for shopping with WasteWisePro!';

    if (status == 'Cancelled') {
      footerText = 'This order has been cancelled.';
    } else if (status == 'Delivered') {
      footerText = 'Thank you for shopping with WasteWisePro! Your order has been delivered.';
    }

    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text(
          footerText,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _getStatusColor(status),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'This is a computer-generated invoice and does not require a signature.',
          style: const pw.TextStyle(
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCancellationWatermark() {
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.2,
        child: pw.Transform.rotate(
          angle: -0.5,
          child: pw.Text(
            'CANCELLED',
            style: pw.TextStyle(
              color: PdfColors.red,
              fontWeight: pw.FontWeight.bold,
              fontSize: 100,
            ),
          ),
        ),
      ),
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return PdfColors.green;
      case 'Cancelled':
        return PdfColors.red;
      case 'Processing':
        return PdfColors.blue;
      default:
        return PdfColors.black;
    }
  }
}