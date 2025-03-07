import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animations/animations.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

class notification extends StatelessWidget {
  const notification({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildNotificationList(context),
    );
  }

  Widget _buildNotificationList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notification')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final notifications = snapshot.data!.docs;

        return AnimationLimiter(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 16),
            itemCount: notifications.length,
            physics: BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildNotificationCard(context, notification),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, DocumentSnapshot notification) {
    final String subscriptionType = notification['type'] as String; // New field
    final String message;

    // Determine the success message based on subscription type
    if (subscriptionType == 'Monthly') {
      message = 'Monthly subscription activated successfully!';
    } else if (subscriptionType == 'Weekly') {
      message = 'Weekly subscription activated successfully!';
    } else {
      message = notification['message'] as String; // Fallback to the original message
    }

    return OpenContainer(
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      transitionType: ContainerTransitionType.fadeThrough,
      openBuilder: (context, _) => _buildDetailView(
        context: context,
        message: notification['message'] as String, // Original message for details
        timestamp: (notification['timestamp'] as Timestamp).toDate(),
        startDate: (notification['start_date'] as Timestamp).toDate(),
        endDate: (notification['end_date'] as Timestamp).toDate(),
        time: notification['time'] as String?,
        pickupAddress: notification['pickup_address'] as String?,
        isCurrentLocation: notification['is_current_location'] as bool?,
        price: notification['price'] as double?,
      ),
      closedBuilder: (context, openContainer) => GestureDetector(
        onTap: openContainer,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(12),
            leading: Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.notifications_active_outlined,
                color: Colors.green.shade600,
                size: 28,
              ),
            ),
            title: Text(
              message, // Display the success message
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                _getTimeDifference((notification['timestamp'] as Timestamp).toDate()),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: Colors.green.shade600,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView({
    required BuildContext context,
    required String message,
    required DateTime timestamp,
    required DateTime startDate,
    required DateTime endDate,
    String? time,
    String? pickupAddress,
    bool? isCurrentLocation,
    double? price,
  }) {
    final duration = endDate.difference(startDate).inDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Details',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard(
                        icon: Icons.calendar_today,
                        title: '$duration Days',
                        subtitle: 'Duration',
                      ),
                      if (price != null)
                        _buildSummaryCard(
                          icon: Icons.payments_outlined,
                          title: '₹${price.toStringAsFixed(2)}',
                          subtitle: 'Amount',
                        ),
                      _buildSummaryCard(
                        icon: Icons.access_time,
                        title: DateFormat('hh:mm a').format(timestamp),
                        subtitle: 'Activated',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Details Section
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDetailItem(
                          icon: Icons.calendar_today_rounded,
                          label: 'Start Date',
                          value: DateFormat('dd MMM yyyy').format(startDate),
                        ),
                        _buildDivider(),
                        _buildDetailItem(
                          icon: Icons.calendar_month_rounded,
                          label: 'End Date',
                          value: DateFormat('dd MMM yyyy').format(endDate),
                        ),
                        if (time != null) ...[
                          _buildDivider(),
                          _buildDetailItem(
                            icon: Icons.access_time_rounded,
                            label: 'Preferred Time',
                            value: time,
                          ),
                        ],
                        if (pickupAddress != null) ...[
                          _buildDivider(),
                          _buildDetailItem(
                            icon: Icons.location_on,
                            label: 'Pickup Location',
                            value: isCurrentLocation == true
                                ? 'Current Location'
                                : pickupAddress,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Section
                  SizedBox(height: 24),
                  Text(
                    'Status Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subscription Active',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'Activated ${_getTimeDifference(timestamp)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade600,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.green.shade600,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeDifference(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays <= 7) {
      return "${difference.inDays} days ago";
    } else {
      return DateFormat("dd MMM yyyy, hh:mm a").format(timestamp);
    }
  }
}