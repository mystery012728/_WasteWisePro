import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final Color primaryGreen = const Color(0xFF2E7D32);
  bool isLoading = true;

  // Statistics
  int totalUsers = 0;
  double totalEarnings = 0.0;
  int totalPickups = 0;

  // User data
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load simple statistics
      await _loadBasicStats();

      // Load users
      await _loadUsers();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading admin data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadBasicStats() async {
    // Get total users count
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('user_details')
        .get();

    totalUsers = usersSnapshot.docs.length;

    // Get total earnings
    final paymentsSnapshot = await FirebaseFirestore.instance
        .collection('successful_payments')
        .get();

    for (var doc in paymentsSnapshot.docs) {
      totalEarnings += (doc.data()['amount'] as num).toDouble();
    }

    // Get pickup counts
    final successfulPickupsSnapshot = await FirebaseFirestore.instance
        .collection('successful_pickups')
        .get();

    totalPickups = successfulPickupsSnapshot.docs.length;
  }

  Future<void> _loadUsers() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('user_details')
        .orderBy('lastUpdated', descending: true)
        .get();

    users = [];

    for (var doc in usersSnapshot.docs) {
      final userData = doc.data();

      // Get subscription status
      bool hasActiveSubscription = false;
      String subscriptionType = 'None';
      DateTime? subscriptionEnd;

      final subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('subscription_details')
          .where('userId', isEqualTo: doc.id)
          .where('status', isEqualTo: 'active')
          .get();

      if (subscriptionSnapshot.docs.isNotEmpty) {
        hasActiveSubscription = true;
        final subData = subscriptionSnapshot.docs.first.data();
        subscriptionType = subData['subscription_type'] ?? 'Unknown';
        subscriptionEnd = (subData['end_date'] as Timestamp?)?.toDate();
      }

      // Get total spent
      double totalSpent = 0.0;
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('successful_payments')
          .where('userId', isEqualTo: doc.id)
          .get();

      for (var payment in paymentsSnapshot.docs) {
        totalSpent += (payment.data()['amount'] as num).toDouble();
      }

      // Get pickup count
      final pickupsSnapshot = await FirebaseFirestore.instance
          .collection('successful_pickups')
          .where('customer_id', isEqualTo: doc.id)
          .get();

      users.add({
        'id': doc.id,
        'name': userData['fullName'] ?? 'Unknown',
        'email': userData['email'] ?? 'No email',
        'mobile': userData['mobile'] ?? 'No mobile',
        'address': userData['address'] ?? 'No address',
        'hasSubscription': hasActiveSubscription,
        'subscriptionType': subscriptionType,
        'subscriptionEnd': subscriptionEnd,
        'totalSpent': totalSpent,
        'pickupCount': pickupsSnapshot.docs.length,
        'lastUpdated': userData['lastUpdated'] as Timestamp?,
        'profilePhotoUrl': userData['profilePhotoUrl'] ?? '',
      });
    }

    filteredUsers = List.from(users);
  }

  void _filterUsers(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredUsers = List.from(users);
      } else {
        filteredUsers = users.where((user) {
          final name = user['name'].toString().toLowerCase();
          final email = user['email'].toString().toLowerCase();
          final mobile = user['mobile'].toString().toLowerCase();
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) ||
              email.contains(searchLower) ||
              mobile.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryGreen,
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Search users by name, email, or mobile...',
                prefixIcon: Icon(Icons.search, color: primaryGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryGreen, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(),
            ),
          ),
          // Quick stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildSimpleStat("Users", totalUsers.toString(), Icons.people),
                _buildSimpleStat("Earnings", "₹${totalEarnings.toStringAsFixed(0)}", Icons.attach_money),
                _buildSimpleStat("Pickups", totalPickups.toString(), Icons.local_shipping),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // User list
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
              child: Text(
                searchQuery.isEmpty
                    ? 'No users found'
                    : 'No users matching "$searchQuery"',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: primaryGreen),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage: user['profilePhotoUrl'].isNotEmpty
              ? NetworkImage(user['profilePhotoUrl'])
              : null,
          child: user['profilePhotoUrl'].isEmpty
              ? Text(
            user['name'].toString().isNotEmpty
                ? user['name'].toString()[0].toUpperCase()
                : '?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          )
              : null,
          backgroundColor: primaryGreen,
        ),
        title: Text(
          user['name'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          user['email'],
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: user['hasSubscription']
                ? Colors.green.shade100
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user['hasSubscription']
                ? user['subscriptionType']
                : 'No Subscription',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: user['hasSubscription']
                  ? Colors.green.shade800
                  : Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserDetailRow('Mobile', user['mobile']),
                const SizedBox(height: 8),
                _buildUserDetailRow('Address', user['address']),
                const SizedBox(height: 8),
                _buildUserDetailRow(
                  'Subscription Ends',
                  user['subscriptionEnd'] != null
                      ? DateFormat('dd MMM yyyy')
                      .format(user['subscriptionEnd'])
                      : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildUserDetailRow(
                  'Total Spent',
                  '₹${user['totalSpent'].toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildUserDetailRow(
                  'Pickup Count',
                  user['pickupCount'].toString(),
                ),
                const SizedBox(height: 8),
                _buildUserDetailRow(
                  'Last Updated',
                  user['lastUpdated'] != null
                      ? DateFormat('dd MMM yyyy, hh:mm a')
                      .format(user['lastUpdated'].toDate())
                      : 'N/A',
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        _viewUserDetails(user);
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: BorderSide(color: primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        _sendNotification(user);
                      },
                      icon: const Icon(Icons.notifications_active, size: 18),
                      label: const Text('Send Notification'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(),
          ),
        ),
      ],
    );
  }

  void _viewUserDetails(Map<String, dynamic> user) {
    // Show a detailed view of the user
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'User Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user['profilePhotoUrl'].isNotEmpty
                      ? NetworkImage(user['profilePhotoUrl'])
                      : null,
                  child: user['profilePhotoUrl'].isEmpty
                      ? Text(
                    user['name'].toString().isNotEmpty
                        ? user['name'].toString()[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                      : null,
                  backgroundColor: primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              _buildUserDetailRow('Name', user['name']),
              const SizedBox(height: 8),
              _buildUserDetailRow('Email', user['email']),
              const SizedBox(height: 8),
              _buildUserDetailRow('Mobile', user['mobile']),
              const SizedBox(height: 8),
              _buildUserDetailRow('Address', user['address']),
              const SizedBox(height: 8),
              _buildUserDetailRow(
                'Subscription',
                user['hasSubscription'] ? user['subscriptionType'] : 'None',
              ),
              const SizedBox(height: 8),
              _buildUserDetailRow(
                'Subscription Ends',
                user['subscriptionEnd'] != null
                    ? DateFormat('dd MMM yyyy').format(user['subscriptionEnd'])
                    : 'N/A',
              ),
              const SizedBox(height: 8),
              _buildUserDetailRow(
                'Total Spent',
                '₹${user['totalSpent'].toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _buildUserDetailRow(
                'Pickup Count',
                user['pickupCount'].toString(),
              ),
              const SizedBox(height: 8),
              _buildUserDetailRow(
                'Last Updated',
                user['lastUpdated'] != null
                    ? DateFormat('dd MMM yyyy, hh:mm a')
                    .format(user['lastUpdated'].toDate())
                    : 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _sendNotification(Map<String, dynamic> user) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Send Notification',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sending notification to ${user['name']}',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Notification Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryGreen, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Notification Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryGreen, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && messageController.text.isNotEmpty) {
                _sendUserNotification(user, titleController.text, messageController.text);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please fill in both title and message'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Send',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendUserNotification(Map<String, dynamic> user, String title, String message) async {
    try {
      // Add notification to Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user['id'],
        'title': title,
        'message': message,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sent to ${user['name']}'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error sending notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send notification: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}