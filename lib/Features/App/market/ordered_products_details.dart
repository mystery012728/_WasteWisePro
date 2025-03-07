  import 'package:flutter/material.dart';
  import 'package:flutternew/Features/App/profile/invoice_generator.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:share_plus/share_plus.dart';
  import 'dart:io';
  import 'dart:math';
  
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
        final random = Random();
        final hour = 9 + random.nextInt(13); // 9 AM to 9 PM
        final minute = random.nextInt(60);
        _deliveryTime =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
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
        final file = await InvoiceGenerator.generateInvoice(_orderDetails);
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
        final file = await InvoiceGenerator.generateInvoice(_orderDetails);
        if (!mounted) return;
  
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invoice downloaded successfully: ${file.path}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () async {
                await Share.shareFiles([file.path]);
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
  
    @override
    Widget build(BuildContext context) {
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
      final total = subtotal + cgst + sgst;
  
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
  
      return ElevatedButton.icon(
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