import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/profile/invoice_generator.dart';
import 'package:flutternew/Features/App/profile/replace_product_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:math';
import 'package:open_file/open_file.dart';
import 'product_rating_page.dart';

class OrderedProductDetails extends StatefulWidget {
  final Map<String, dynamic> orderDetails;
  final VoidCallback onOrderCancelled;

  const OrderedProductDetails({
    Key? key,
    required this.orderDetails,
    required this.onOrderCancelled,
  }) : super(key: key);

  @override
  State<OrderedProductDetails> createState() => _OrderedProductDetailsState();
}

class _OrderedProductDetailsState extends State<OrderedProductDetails> {
  late Map<String, dynamic> _orderDetails;
  String? _deliveryTime;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _orderDetails = Map<String, dynamic>.from(widget.orderDetails);
    _generateDeliveryTime();
  }

  void _generateDeliveryTime() {
    if (_orderDetails['status'] == 'Delivered') {
      // If we already have a predicted time, use that
      if (_orderDetails['predictedDeliveryTime'] != null) {
        _deliveryTime = _orderDetails['predictedDeliveryTime'];
      } else {
        // Otherwise generate a random time
        final random = Random();
        final hour = 9 + random.nextInt(13); // 9 AM to 9 PM
        final minute = random.nextInt(60);
        _deliveryTime =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }
  }

  DateTime _parseDeliveryDate(String dateStr) {
    // Parse date in format DD/MM/YYYY
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );
    }
    return DateTime.now(); // fallback
  }

  bool _isOneDayBeforeDelivery() {
    if (_orderDetails['deliveryDate'] == null) return false;

    final deliveryDate = _parseDeliveryDate(_orderDetails['deliveryDate']);
    final now = DateTime.now();
    final oneDayBefore = deliveryDate.subtract(const Duration(days: 1));

    return now.year == oneDayBefore.year &&
        now.month == oneDayBefore.month &&
        now.day == oneDayBefore.day;
  }

  Future<void> _cancelOrder() async {
    try {
      final orderId = _orderDetails['orderId'];

      // Store in cancelled_orders collection
      await _firestore.collection('cancelled_orders').doc(orderId).set({
        ..._orderDetails,
        'status': 'Cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
      });

      // Delete from orders collection
      await _firestore.collection('orders').doc(orderId).delete();

      setState(() {
        _orderDetails['status'] = 'Cancelled';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order cancelled successfully',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );

      widget.onOrderCancelled();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to cancel order: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareInvoice() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating invoice...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Generate the invoice
      final file = await InvoiceGenerator.generateInvoice(_orderDetails);

      // Share the invoice
      await Share.shareFiles(
        [file.path],
        text: 'Order Invoice #${_orderDetails['orderId']}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to generate invoice: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadInvoice() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating invoice...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }

      final file = await InvoiceGenerator.generateInvoice(_orderDetails);
      if (!mounted) return;

      // Determine where the file was saved
      String locationDescription = '';
      if (file.path.contains('/storage/emulated/0/Download')) {
        locationDescription = 'Downloads folder';
      } else if (file.path.contains('Documents')) {
        locationDescription = 'Documents folder';
      } else {
        locationDescription = 'App storage';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice downloaded successfully!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Saved to: $locationDescription',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                ),
              ),
              Text(
                file.path,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () async {
              try {
                // Try to open the file using the open_file plugin
                final result = await OpenFile.open(file.path);
                if (result.type != ResultType.done) {
                  // If can't open directly, share it instead
                  await Share.shareFiles([file.path]);
                }
              } catch (e) {
                // Fallback to sharing if opening fails
                await Share.shareFiles([file.path]);
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download invoice: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRatingDialog() {
    final items = _orderDetails['items'] as List<dynamic>;

    // Add debugging to log item structure
    print('Items to rate: ${items.length}');
    for (var item in items) {
      print(
          'Item: ${item['title']}, Product ID: ${item['productId'] ?? 'MISSING'}');
    }

    // Ensure all items have a productId
    for (var item in items) {
      if (!item.containsKey('productId') && item.containsKey('id')) {
        item['productId'] = item['id'];
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rate & Review',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Choose a product to rate:'),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // Skip items without productId
                    if (!item.containsKey('productId')) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          item['image'],
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        item['title'],
                        style: GoogleFonts.poppins(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Product ID: ${item['productId']}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToRatingPage(item);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToRatingPage(Map<String, dynamic> product) {
    // Determine the collection name based on product type or category
    String collectionName = 'products'; // Default to products (fertilizers)

    // Make sure we have a valid productId
    if (!product.containsKey('productId')) {
      // Show error if no productId
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot rate this product: missing product ID',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check product type/category if available
    if (product.containsKey('category')) {
      if (product['category'] == 'recycled_craft') {
        collectionName = 'recycled_products';
      } else if (product['category'] == 'recycled_electronics') {
        collectionName = 'recycled_electronics';
      }
    }

    // Log for debugging
    print(
        'Navigating to rating page with productId: ${product['productId']} and collection: $collectionName');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductRatingPage(
          product: product,
          collectionName: collectionName,
          orderId: _orderDetails['orderId'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isProcessing = _orderDetails['status'] == 'Processing';
    final bool hasDeliveryDate = _orderDetails['deliveryDate'] != null;
    final bool hasDeliveryTime = _orderDetails['predictedDeliveryTime'] != null;
    final bool isOneDayBeforeDelivery =
        hasDeliveryDate && isProcessing && _isOneDayBeforeDelivery();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          if (_orderDetails['status'] != 'Cancelled')
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareInvoice,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderStatusCard(),
            if (isOneDayBeforeDelivery && hasDeliveryTime) ...[
              const SizedBox(height: 16),
              _buildDeliveryTimeCard(),
            ],
            const SizedBox(height: 20),
            _buildDeliveryAddressCard(),
            const SizedBox(height: 20),
            _buildOrderItemsList(),
            const SizedBox(height: 20),
            _buildPriceDetails(),
            const SizedBox(height: 20),
            _buildDownloadInvoiceButton(),
          ],
        ),
      ),
      bottomNavigationBar:
      _orderDetails['status'] == 'Processing' ? _buildCancelButton() : null,
    );
  }

  Widget _buildDeliveryTimeCard() {
    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Time Confirmed!',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your order will be delivered tomorrow at ${_orderDetails['predictedDeliveryTime']}',
                    style: GoogleFonts.poppins(
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${_orderDetails['orderId']}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Date:',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                Text(
                  _orderDetails['orderDate'],
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status:',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                _buildStatusChip(_orderDetails['status']),
              ],
            ),
            if (_orderDetails['status'] == 'Processing' &&
                _orderDetails['deliveryDate'] != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expected Delivery:',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  Text(
                    _orderDetails['deliveryDate'],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (_deliveryTime != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery Time:',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  Text(
                    _deliveryTime!,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'Processing':
        chipColor = Colors.blue;
        break;
      case 'Delivered':
        chipColor = Colors.green;
        break;
      case 'Cancelled':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          color: chipColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    final address = _orderDetails['shippingAddress'] as Map<String, dynamic>;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Text(
                  'Delivery Address',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              address['name'] ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '${address['house']}, ${address['road']}',
              style: GoogleFonts.poppins(),
            ),
            Text(
              '${address['city']}, ${address['state']}',
              style: GoogleFonts.poppins(),
            ),
            Text(
              'PIN: ${address['pincode']}',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 4),
            Text(
              'Phone: ${address['phone']}',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsList() {
    final items = _orderDetails['items'] as List<dynamic>;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                // Ensure item has a productId
                if (!item.containsKey('productId')) {
                  // If no productId, try to use the id field if available
                  if (item.containsKey('id')) {
                    item['productId'] = item['id'];
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['image'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quantity: ${item['quantity']}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (item.containsKey('productId')) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Product ID: ${item['productId']}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDetails() {
    final subtotal = _orderDetails['totalAmount'] as num;
    final cgst = subtotal * 0.09;
    final sgst = subtotal * 0.09;
    final deliveryCharges = subtotal < 299 ? 99 : 0;
    final total = subtotal + cgst + sgst + deliveryCharges;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPriceRow('Subtotal', subtotal),
            _buildPriceRow('CGST (9%)', cgst),
            _buildPriceRow('SGST (9%)', sgst),
            _buildPriceRow('Delivery Charges', deliveryCharges),
            if (subtotal < 299)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'FREE delivery Over ₹299',
                  style: GoogleFonts.poppins(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Free Delivery. (Order value over ₹299)',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            _buildPriceRow('Total Amount', total, isTotal: true),
            const SizedBox(height: 8),
            Text(
              'Payment Method: ${_orderDetails['paymentMethod']}',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, num amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: isTotal ? FontWeight.bold : null,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontWeight: isTotal ? FontWeight.bold : null,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? const Color(0xFF2E7D32) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadInvoiceButton() {
    // Don't show download button for processing orders
    if (_orderDetails['status'] == 'Processing') {
      return const SizedBox.shrink();
    }

    Color buttonColor;
    IconData buttonIcon;
    String buttonText;

    switch (_orderDetails['status']) {
      case 'Delivered':
        buttonColor = Colors.green;
        buttonIcon = Icons.check_circle;
        buttonText = 'Download Completed Invoice';
        break;
      case 'Cancelled':
        buttonColor = Colors.red;
        buttonIcon = Icons.cancel;
        buttonText = 'Download Cancelled Invoice';
        break;
      default:
        buttonColor = Colors.blue;
        buttonIcon = Icons.receipt;
        buttonText = 'Download Invoice';
    }

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _downloadInvoice,
          icon: Icon(buttonIcon, color: Colors.white),
          label: Text(
            buttonText,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        if (_orderDetails['status'] == 'Delivered') ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReplaceProductPage(orderDetails: _orderDetails),
                ),
              );
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: Text(
              'Return/Replace Product',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showRatingDialog,
            icon: const Icon(Icons.star, color: Colors.white),
            label: Text(
              'Rate & Review Product',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCancelButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _cancelOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          'Cancel Order',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
