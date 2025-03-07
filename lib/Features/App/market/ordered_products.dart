import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/market/ordered_products_details.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class OrderedProducts extends StatefulWidget {
  const OrderedProducts({Key? key}) : super(key: key);

  @override
  State<OrderedProducts> createState() => _OrderedProductsState();
}

class _OrderedProductsState extends State<OrderedProducts>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> orders = [];
  Timer? _timer;
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
    // Check for order updates every minute
    _timer =
        Timer.periodic(const Duration(minutes: 1), (_) => _checkOrderUpdates());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
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

      // Combine all orders
      allOrders.addAll(ordersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList());
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
      for (var doc in ordersSnapshot.docs) {
        final order = doc.data() as Map<String, dynamic>;
        final deliveryDate =
        DateTime.parse(order['deliveryDate'].split('/').reversed.join('-'));

        if (DateTime.now().isAfter(deliveryDate)) {
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

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Text(
                'Processing',
                style: GoogleFonts.poppins(),
              ),
            ),
            Tab(
              child: Text(
                'Completed',
                style: GoogleFonts.poppins(),
              ),
            ),
            Tab(
              child: Text(
                'Cancelled',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(_getFilteredOrders('Processing')),
          _buildOrdersList(_getFilteredOrders('Delivered')),
          _buildOrdersList(_getFilteredOrders('Cancelled')),
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

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List<dynamic>;
    final firstItem = items.first;
    final itemCount = items.length;

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
                  if (order['status'] == 'Processing')
                    Text(
                      'Delivery by ${order['deliveryDate']}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
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
