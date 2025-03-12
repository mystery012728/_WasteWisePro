import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/market/ordered_products_details.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';

class OrderedProducts extends StatefulWidget {
  const OrderedProducts({Key? key}) : super(key: key);

  @override
  State<OrderedProducts> createState() => _OrderedProductsState();
}

class _OrderedProductsState extends State<OrderedProducts> {
  List<Map<String, dynamic>> orders = [];
  Timer? _timer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;

  // Track which view is selected (0 = Processing, 1 = Completed, 2 = Cancelled)
  int _selectedView = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Check for order updates every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkOrderUpdates());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (_userId == null) return;

    try {
      final List<Map<String, dynamic>> allOrders = [];

      // Get orders from main orders collection
      final QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();

      // Get successful orders
      final QuerySnapshot successfulOrdersSnapshot = await _firestore
          .collection('successful_orders')
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();

      // Get cancelled orders
      final QuerySnapshot cancelledOrdersSnapshot = await _firestore
          .collection('cancelled_orders')
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();

      // Process orders and add delivery time prediction if needed
      for (var doc in ordersSnapshot.docs) {
        final order = doc.data() as Map<String, dynamic>;

        // Check if we need to add a delivery time prediction
        if (order['status'] == 'Processing' && order['deliveryDate'] != null) {
          final deliveryDate = _parseDeliveryDate(order['deliveryDate']);
          final now = DateTime.now();
          final oneDayBefore = deliveryDate.subtract(const Duration(days: 1));

          // If today is one day before delivery and no predicted time yet
          if (now.year == oneDayBefore.year &&
              now.month == oneDayBefore.month &&
              now.day == oneDayBefore.day &&
              order['predictedDeliveryTime'] == null) {

            // Generate random delivery time between 10 AM and 7 PM
            final random = Random();
            final hour = 10 + random.nextInt(10); // 10 AM to 7 PM (10+9)
            final minute = random.nextInt(60);
            final predictedTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

            // Update the order with predicted delivery time
            await _firestore.collection('orders').doc(doc.id).update({
              'predictedDeliveryTime': predictedTime,
            });

            order['predictedDeliveryTime'] = predictedTime;
          }
        }

        allOrders.add(order);
      }

      // Add successful and cancelled orders
      allOrders.addAll(successfulOrdersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList());
      allOrders.addAll(cancelledOrdersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList());

      setState(() {
        orders = allOrders;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading orders: $e');
      setState(() {
        _isLoading = false;
      });
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

  List<Map<String, dynamic>> _getFilteredOrders(String status) {
    return orders.where((order) => order['status'] == status).toList();
  }

  Future<void> _checkOrderUpdates() async {
    if (_userId == null) return;

    try {
      final QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: _userId)
          .where('status', isEqualTo: 'Processing')
          .get();

      bool hasChanges = false;
      final now = DateTime.now();

      for (var doc in ordersSnapshot.docs) {
        final order = doc.data() as Map<String, dynamic>;
        final deliveryDate = _parseDeliveryDate(order['deliveryDate']);

        // Check if delivery date has passed
        if (now.isAfter(deliveryDate)) {
          // If we have a predicted time, check if that time has passed too
          bool shouldMarkDelivered = true;

          if (order['predictedDeliveryTime'] != null) {
            final timeStr = order['predictedDeliveryTime'] as String;
            final timeParts = timeStr.split(':');
            if (timeParts.length == 2) {
              final deliveryDateTime = DateTime(
                deliveryDate.year,
                deliveryDate.month,
                deliveryDate.day,
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );

              // Only mark as delivered if current time is after the predicted delivery time
              shouldMarkDelivered = now.isAfter(deliveryDateTime);
            }
          }

          if (shouldMarkDelivered) {
            // Update order status
            await _firestore
                .collection('orders')
                .doc(doc.id)
                .update({'status': 'Delivered'});

            // Store in successful_orders collection
            await _firestore.collection('successful_orders').doc(doc.id).set({
              ...order,
              'status': 'Delivered',
              'completedAt': DateTime.now().toIso8601String(),
            });

            // Delete from orders collection
            await _firestore.collection('orders').doc(doc.id).delete();

            hasChanges = true;
          }
        }
      }

      if (hasChanges) {
        _loadOrders();
      }
    } catch (e) {
      print('Error checking order updates: $e');
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> filteredOrders) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF2E7D32),
        ),
      );
    }

    if (filteredOrders.isEmpty) {
      return _buildEmptyState('No orders in this section');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return OrderCard(
          order: order,
          onStatusChanged: () {
            _loadOrders();
          },
        );
      },
    );
  }

  Widget _buildToggleBar() {
    return Container(
      color: const Color(0xFF2E7D32),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.shade800,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedView = 0;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedView == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Processing',
                      style: GoogleFonts.poppins(
                        color: _selectedView == 0
                            ? const Color(0xFF2E7D32)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedView = 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedView == 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Completed',
                      style: GoogleFonts.poppins(
                        color: _selectedView == 1
                            ? const Color(0xFF2E7D32)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedView = 2;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedView == 2 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Cancelled',
                      style: GoogleFonts.poppins(
                        color: _selectedView == 2
                            ? const Color(0xFF2E7D32)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the appropriate filtered orders based on selected view
    List<Map<String, dynamic>> filteredOrders;
    switch (_selectedView) {
      case 0:
        filteredOrders = _getFilteredOrders('Processing');
        break;
      case 1:
        filteredOrders = _getFilteredOrders('Delivered');
        break;
      case 2:
        filteredOrders = _getFilteredOrders('Cancelled');
        break;
      default:
        filteredOrders = _getFilteredOrders('Processing');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildToggleBar(),
          Expanded(
            child: _buildOrdersList(filteredOrders),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onStatusChanged;

  const OrderCard({
    Key? key,
    required this.order,
    required this.onStatusChanged,
  }) : super(key: key);

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

  bool _isOneDayBeforeDelivery(String deliveryDateStr) {
    final deliveryDate = _parseDeliveryDate(deliveryDateStr);
    final now = DateTime.now();
    final oneDayBefore = deliveryDate.subtract(const Duration(days: 1));

    return now.year == oneDayBefore.year &&
        now.month == oneDayBefore.month &&
        now.day == oneDayBefore.day;
  }

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List<dynamic>;
    final firstItem = items.first;
    final itemCount = items.length;
    final bool isProcessing = order['status'] == 'Processing';
    final bool hasDeliveryDate = order['deliveryDate'] != null;
    final bool hasDeliveryTime = order['predictedDeliveryTime'] != null;
    final bool isOneDayBeforeDelivery = hasDeliveryDate &&
        isProcessing &&
        _isOneDayBeforeDelivery(order['deliveryDate']);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderedProductDetails(
                orderDetails: order,
                onOrderCancelled: onStatusChanged,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order['orderId']}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusChip(order['status']),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      firstItem['image'],
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
                          firstItem['title'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (itemCount > 1)
                          Text(
                            '+${itemCount - 1} more items',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${order['totalAmount'].toStringAsFixed(2)}',
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ordered on ${order['orderDate']}',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (isProcessing && hasDeliveryDate)
                    Text(
                      'Delivery by ${order['deliveryDate']}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              if (isOneDayBeforeDelivery && hasDeliveryTime) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Your delivery will arrive tomorrow at ${order['predictedDeliveryTime']}',
                          style: GoogleFonts.poppins(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
          fontSize: 12,
        ),
      ),
    );
  }
}