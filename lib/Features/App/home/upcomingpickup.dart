import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/home/tracking.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpcomingPickUpPage extends StatefulWidget {
  @override
  _UpcomingPickUpPageState createState() => _UpcomingPickUpPageState();
}

class _UpcomingPickUpPageState extends State<UpcomingPickUpPage> {
  final Color primaryGreen = const Color(0xFF2E7D32);
  Map<String, bool> cancelledSubscriptions = {};
  Map<String, bool> confirmedPickups = {};
  Map<String, bool> missedPickups = {};

  @override
  void initState() {
    super.initState();
    NotificationUtils.initialize();
    _loadCancelledAndConfirmedPickups();
    _checkSubscriptionValidity();
  }

  Future<void> _loadCancelledAndConfirmedPickups() async {
    await _loadCancelledSubscriptions();
    await _loadConfirmedPickups();
    await _loadMissedPickups();
  }

  Future<void> _loadCancelledSubscriptions() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cancelledDocs = await FirebaseFirestore.instance
        .collection('cancelled_pickups')
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .get();

    setState(() {
      for (var doc in cancelledDocs.docs) {
        cancelledSubscriptions[doc.data()['subscription_id']] = true;
      }
    });
  }

  Future<void> _loadConfirmedPickups() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final confirmedDocs = await FirebaseFirestore.instance
        .collection('successful_pickups')
        .where('pickup_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('pickup_date',
        isLessThanOrEqualTo:
        Timestamp.fromDate(today.add(Duration(days: 1))))
        .get();

    setState(() {
      for (var doc in confirmedDocs.docs) {
        final data = doc.data();
        if (data['subscription_id'] != null) {
          confirmedPickups[data['subscription_id']] = true;
        }
        if (data['special_day_id'] != null) {
          confirmedPickups[data['special_day_id']] = true;
        }
      }
    });
  }

  Future<void> _loadMissedPickups() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final missedDocs = await FirebaseFirestore.instance
        .collection('missed_pickups')
        .where('missed_at', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('missed_at',
        isLessThanOrEqualTo:
        Timestamp.fromDate(today.add(Duration(days: 1))))
        .get();

    setState(() {
      for (var doc in missedDocs.docs) {
        final data = doc.data();
        if (data['subscription_id'] != null) {
          missedPickups[data['subscription_id']] = true;
        }
        if (data['special_day_id'] != null) {
          missedPickups[data['special_day_id']] = true;
        }
      }
    });
  }

  bool isSubscriptionCancelledForToday(String subscriptionId) {
    return cancelledSubscriptions[subscriptionId] ?? false;
  }

  bool isPickupConfirmedForToday(String id) {
    return confirmedPickups[id] ?? false;
  }

  bool isPickupMissedForToday(String id) {
    return missedPickups[id] ?? false;
  }

  bool _isWithinPickupWindow(String pickupTime) {
    try {
      final format = DateFormat("hh:mm a");
      final now = DateTime.now();
      final pickupDateTime = format.parse(pickupTime);

      final scheduledPickup = DateTime(
        now.year,
        now.month,
        now.day,
        pickupDateTime.hour,
        pickupDateTime.minute,
      );

      final pickupWindowEnd = scheduledPickup.add(Duration(minutes: 30));
      return now.isBefore(pickupWindowEnd) &&
          now.isAfter(scheduledPickup.subtract(Duration(minutes: 1)));
    } catch (e) {
      print('Error parsing pickup time: $e');
      return false;
    }
  }

  Future<void> _checkSubscriptionValidity() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscription_details')
        .where('payment_status', isEqualTo: 'completed')
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final endDate = (data['end_date'] as Timestamp).toDate();
      final now = DateTime.now();

      // Schedule notification 1 day before expiration
      if (endDate.isBefore(now.add(Duration(days: 1))) &&
          endDate.isAfter(now)) {
        NotificationUtils.createExpirationNotification();

        // Create notification in Firestore
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'user_id': userId,
            'message':
            'Your subscription will expire in 1 day. Please renew it.',
            'created_at': Timestamp.now(),
            'read': false,
            'type': 'subscription_expiring'
          });
        }
      }

      // Check if the subscription is expired
      if (now.isAfter(endDate)) {
        // Update subscription status to deactivated
        await doc.reference.update({'status': 'deactivated'});
        NotificationUtils.createDeactivationNotification();

        // Create notification in Firestore
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'user_id': userId,
            'message':
            'Your subscription has expired. Please renew to continue enjoying our services.',
            'created_at': Timestamp.now(),
            'read': false,
            'type': 'subscription_expired'
          });
        }
      }
    }

    // Check for expired special day pickups
    final specialDaySnapshot = await FirebaseFirestore.instance
        .collection('special_day_details')
        .where('payment_status', isEqualTo: 'completed')
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in specialDaySnapshot.docs) {
      final data = doc.data();
      final pickupDate = (data['pickup_date'] as Timestamp).toDate();
      final now = DateTime.now();

      // Check if the special day pickup is expired
      if (now.isAfter(pickupDate)) {
        // Update special day pickup status to deactivated
        await doc.reference.update({'status': 'deactivated'});
        NotificationUtils.createDeactivationNotification();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubscriptionPickups(),
                    const SizedBox(height: 20),
                    _buildSpecialDayPickups(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Upcoming Pick Up',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_today, color: primaryGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Upcoming Pickup',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildSubscriptionPickups() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Center(
        child: Text(
          'Please login to view your pickups',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscription_details')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'active')
          .where('payment_status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Pickups',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildSubscriptionCard(data, doc.id, context);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSpecialDayPickups() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Center(
        child: Text(
          'Please login to view your pickups',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('special_day_details')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'active')
          .where('payment_status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Special Day Pickups',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildSpecialDayCard(data, doc.id, context);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionCard(
      Map<String, dynamic> data, String docId, BuildContext context) {
    final startDate = (data['start_date'] as Timestamp).toDate();
    final endDate = (data['end_date'] as Timestamp).toDate();
    final pickupTime = data['pickup_time'] as String;
    final subscriptionType = data['subscription_type'] as String;
    final isCancelled = isSubscriptionCancelledForToday(docId);
    final isConfirmed = isPickupConfirmedForToday(docId);
    final isWithinWindow = _isWithinPickupWindow(pickupTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.repeat, color: primaryGreen),
            ),
            title: Text(
              '$subscriptionType Subscription',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Pickup Time: $pickupTime',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                Text(
                  'Valid: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  data['pickup_address'],
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s pickup is confirmed',
                          style: GoogleFonts.poppins(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Next pickup scheduled for tomorrow at $pickupTime',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (isPickupMissedForToday(docId))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s pickup was missed',
                          style: GoogleFonts.poppins(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Next pickup scheduled for tomorrow at $pickupTime',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (isCancelled)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s pickup is cancelled',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Service will resume tomorrow at $pickupTime',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: isCancelled
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackPickUpPage(
                          pickupId: docId,
                          collectionName: 'subscription_details',
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.location_on,
                      color: isCancelled ? Colors.grey : primaryGreen),
                  label: Text(
                    'Track',
                    style: GoogleFonts.poppins(
                        color: isCancelled ? Colors.grey : primaryGreen),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: isCancelled
                      ? null
                      : () => _showChangePickupTimeDialog(
                      context, docId, pickupTime),
                  icon: Icon(Icons.access_time,
                      color: isCancelled ? Colors.grey : primaryGreen),
                  label: Text(
                    'Change Time',
                    style: GoogleFonts.poppins(
                        color: isCancelled ? Colors.grey : primaryGreen),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: isCancelled
                      ? null
                      : () => _showCancelDialog(
                      context, docId, 'subscription_details'),
                  icon: Icon(Icons.cancel_outlined,
                      color: isCancelled ? Colors.grey : Colors.red),
                  label: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                        color: isCancelled ? Colors.grey : Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialDayCard(
      Map<String, dynamic> data, String docId, BuildContext context) {
    final pickupDate = (data['pickup_date'] as Timestamp).toDate();
    final pickupTime = data['pickup_time'] as String;
    final type = data['type'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                type == 'waste' ? Icons.delete : Icons.recycling,
                color: primaryGreen,
              ),
            ),
            title: Text(
              'Special ${type.capitalize()} Pickup',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Date: ${DateFormat('MMM d, yyyy').format(pickupDate)}',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                Text(
                  'Time: $pickupTime',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  data['pickup_address'],
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isPickupConfirmedForToday(docId))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Special day pickup is confirmed',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isPickupMissedForToday(docId))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Special day pickup was missed',
                      style: GoogleFonts.poppins(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!_isWithinPickupWindow(pickupTime) &&
                DateTime.now().isAfter(pickupDate))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Special day pickup was missed',
                        style: GoogleFonts.poppins(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackPickUpPage(
                          pickupId: docId,
                          collectionName: 'special_day_details',
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.location_on, color: primaryGreen),
                  label: Text(
                    'Track',
                    style: GoogleFonts.poppins(color: primaryGreen),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      _showCancelDialog(context, docId, 'special_day_details'),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangePickupTimeDialog(
      BuildContext context, String docId, String currentTime) async {
    TimeOfDay initialTime = TimeOfDay(
      hour: int.parse(currentTime.split(':')[0]),
      minute: int.parse(currentTime.split(':')[1].split(' ')[0]),
    );

    showTimePicker(
      context: context,
      initialTime: initialTime,
    ).then((TimeOfDay? newTime) {
      if (newTime != null) {
        if (newTime.hour < 7 || newTime.hour > 23) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select a time between 7 AM and 11 PM.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          _updatePickupTime(context, docId, newTime);
        }
      }
    });
  }

  void _updatePickupTime(
      BuildContext context, String docId, TimeOfDay newTime) {
    FirebaseFirestore.instance
        .collection('subscription_details')
        .doc(docId)
        .update({
      'pickup_time': newTime.format(context),
      'pickup_time_changed': true,
    }).then((_) {
      if (mounted) {
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Pickup rescheduled successfully',
        );
      }
    }).catchError((error) {
      if (mounted) {
        CustomSnackbar.showError(
          context: context,
          message: 'Failed to reschedule pickup. Please try again.',
        );
      }
    });
  }

  void _showCancelDialog(
      BuildContext context, String docId, String collection) async {
    final message = collection == 'subscription_details'
        ? 'Are you sure you want to cancel today\'s pickup? Service will resume tomorrow.'
        : 'Are you sure you want to cancel this special day pickup? This action cannot be undone.';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Cancel Pickup',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'No, Keep it',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (collection == 'subscription_details') {
                  // For subscription pickups - cancel for today only
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  await FirebaseFirestore.instance
                      .collection('cancelled_pickups')
                      .add({
                    'subscription_id': docId,
                    'date': Timestamp.fromDate(today),
                  });

                  setState(() {
                    cancelledSubscriptions[docId] = true;
                  });
                } else {
                  // For special day pickups - deactivate completely
                  await FirebaseFirestore.instance
                      .collection(collection)
                      .doc(docId)
                      .update({
                    'status': 'deactivated',
                  });
                }

                Navigator.pop(context);
                _showCancelConfirmation(context, collection);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Yes, Cancel',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCancelConfirmation(BuildContext context, String collection) {
    final message = collection == 'subscription_details'
        ? 'Today\'s pickup is cancelled. Service will resume tomorrow.'
        : 'Special day pickup has been cancelled.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Notification utility class
class NotificationUtils {
  static void initialize() {
    AwesomeNotifications().initialize(
      'resource_key',
      [
        NotificationChannel(
          channelKey: 'subscription_channel',
          channelName: 'Subscription Notifications',
          channelDescription: 'Notification channel for subscription reminders',
          defaultColor: Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        )
      ],
    );
  }

  static void createExpirationNotification() {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'subscription_channel',
        title: 'Subscription Expiration Reminder',
        body: 'Your subscription will expire in 1 day. Please renew it.',
      ),
    );
  }

  static void createDeactivationNotification() {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'subscription_channel',
        title: 'Subscription Deactivated',
        body:
        'Your subscription has expired. Please renew to continue enjoying our services.',
      ),
    );
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
