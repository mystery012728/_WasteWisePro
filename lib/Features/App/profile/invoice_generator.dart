import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

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
            _buildFooter(orderDetails),
            if (status == 'Cancelled') _buildCancellationWatermark(),
          ];
        },
      ),
    );

    // Generate a meaningful filename with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName =
        'WasteWisePro_Invoice_${orderDetails['orderId']}_${status.toLowerCase()}_$timestamp.pdf';

    // Try to save in Downloads folder first, fallback to temp dir if can't access
    try {
      // Try to get access to external storage
      final status = await Permission.storage.request();

      if (status.isGranted) {
        // On Android, save to Downloads
        if (Platform.isAndroid) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Navigate from Android/data/... to Download
            final downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }

            final file = File('${downloadsDir.path}/$fileName');
            await file.writeAsBytes(await pdf.save());
            return file;
          }
        }
        // On iOS, save to Documents
        else if (Platform.isIOS) {
          final documentsDir = await getApplicationDocumentsDirectory();
          final file = File('${documentsDir.path}/$fileName');
          await file.writeAsBytes(await pdf.save());
          return file;
        }
      }

      // Fallback to temp directory if above fails
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      // If anything goes wrong, fallback to temp directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      return file;
    }
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
    String formattedDate;
    try {
      // Try to parse as ISO date first
      final orderDate = DateTime.parse(orderDetails['orderDate']);
      formattedDate = DateFormat('dd MMM yyyy').format(orderDate);
    } catch (e) {
      // If it fails, assume it's already in DD/MM/YYYY format
      formattedDate = orderDetails['orderDate'];
    }

    final status = orderDetails['status'] as String? ?? 'Processing';
    final statusColor = _getStatusColor(status);

    String statusDetails = status;
    if (status == 'Cancelled' && orderDetails.containsKey('cancelledAt')) {
      final cancelledDate = DateTime.parse(orderDetails['cancelledAt']);
      final formattedCancelDate =
      DateFormat('dd MMM yyyy HH:mm').format(cancelledDate);
      statusDetails = '$status on $formattedCancelDate';
    } else if (status == 'Delivered' &&
        orderDetails.containsKey('deliveredAt')) {
      final deliveredDate = DateTime.parse(orderDetails['deliveredAt']);
      final formattedDeliveryDate =
      DateFormat('dd MMM yyyy').format(deliveredDate);
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
            if (orderDetails.containsKey('deliveryDate') &&
                status == 'Processing')
              pw.Text(
                'Expected Delivery: ${orderDetails['deliveryDate']}',
                style: const pw.TextStyle(fontSize: 14),
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

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ordered Items',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FlexColumnWidth(5),
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

              // Build item description with product ID and any additional details
              String description = item['title'] ?? 'N/A';
              if (item.containsKey('productId')) {
                description += '\nProduct ID: ${item['productId']}';
              } else if (item.containsKey('id')) {
                description += '\nProduct ID: ${item['id']}';
              }

              // Add category if available
              if (item.containsKey('category')) {
                description += '\nCategory: ${item['category']}';
              }

              // Add any other important product details
              if (item.containsKey('brand')) {
                description += '\nBrand: ${item['brand']}';
              }

              if (item.containsKey('weight') || item.containsKey('size')) {
                final weightOrSize = item.containsKey('weight')
                    ? '${item['weight']}'
                    : '${item['size']}';
                description += '\nWeight/Size: $weightOrSize';
              }

              return pw.TableRow(
                children: [
                  _buildTableCell(description),
                  _buildTableCell(quantity.toString()),
                  _buildTableCell('Rs. ${price.toStringAsFixed(2)}'),
                  _buildTableCell('Rs. ${total.toStringAsFixed(2)}'),
                ],
              );
            }).toList(),
          ],
        ),
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

    // Calculate delivery charges based on subtotal
    final deliveryCharges = subtotal < 299 ? 99.0 : 0.0;

    // Include delivery charges in total
    final total = subtotal + cgst + sgst + deliveryCharges;

    return pw.Column(
      children: [
        _buildAmountRow('Subtotal:', subtotal),
        _buildAmountRow('CGST (9%):', cgst),
        _buildAmountRow('SGST (9%):', sgst),
        _buildAmountRow('Delivery Charges:', deliveryCharges),
        if (subtotal >= 299)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2, bottom: 4, left: 8),
            child: pw.Row(
              children: [
                pw.Text(
                  'Free Delivery (Order value over ₹299)',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.green,
                  ),
                ),
              ],
            ),
          ),
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

  static pw.Widget _buildFooter(Map<String, dynamic> orderDetails) {
    final status = orderDetails['status'] as String? ?? 'Processing';
    final orderId = orderDetails['orderId'] ?? '';

    String footerText = 'Thank you for shopping with WasteWisePro!';

    if (status == 'Cancelled') {
      footerText = 'This order has been cancelled.';
    } else if (status == 'Delivered') {
      footerText =
      'Thank you for shopping with WasteWisePro! Your order has been delivered.';
    }

    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'For any query related to this order:',
                    style: const pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    'Email: support@wastewisepro.com | Phone: +91-9876543210',
                    style: const pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Column(
              children: [
                pw.BarcodeWidget(
                  data: 'WasteWisePro-Order-$orderId',
                  width: 80,
                  height: 80,
                  barcode: pw.Barcode.qrCode(),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Scan to Track',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ],
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
