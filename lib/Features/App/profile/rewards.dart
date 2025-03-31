import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RewardsPage extends StatefulWidget {
  const RewardsPage({Key? key}) : super(key: key);

  @override
  _RewardsPageState createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final Color primaryColor = const Color(0xFF2E7D32);
  final double monthlyGoal = 500.0; // Monthly goal in kg
  final double yearlyGoal = 5000.0; // Yearly goal in kg

  double totalWasteCollected = 0.0;
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoading = true;
  String currentMonth = '';
  String currentYear = '';
  bool isMonthlyView = true; // Track which view is selected
  bool isGoalCompleted = false;
  bool isGoalRedeemed = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentMonth = DateFormat('MMMM').format(now);
    currentYear = DateFormat('yyyy').format(now);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    if (isMonthlyView) {
      await _loadMonthlyData();
      await _checkMonthlyGoalRedemptionStatus();
    } else {
      await _loadYearlyData();
      await _checkYearlyGoalRedemptionStatus();
    }
  }

  Future<void> _checkMonthlyGoalRedemptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final key =
        'monthly_goal_redeemed_${userId}_${currentMonth}_${currentYear}';
    setState(() {
      isGoalRedeemed = prefs.getBool(key) ?? false;
    });
  }

  Future<void> _checkYearlyGoalRedemptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final key = 'yearly_goal_redeemed_${userId}_${currentYear}';
    setState(() {
      isGoalRedeemed = prefs.getBool(key) ?? false;
    });
  }

  Future<void> _loadMonthlyData() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0);
    await _fetchPickupData(startDate, endDate);
  }

  Future<void> _loadYearlyData() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, 1, 1);
    final endDate = DateTime(now.year, 12, 31);
    await _fetchPickupData(startDate, endDate);
  }

  Future<void> _fetchPickupData(DateTime startDate, DateTime endDate) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      // Fetch successful pickups (both subscription and special day)
      final successfulPickupsQuery = await FirebaseFirestore.instance
          .collection('successful_pickups')
          .where('customer_id', isEqualTo: userId)
          .where('pickup_date', isGreaterThanOrEqualTo: startDate)
          .where('pickup_date', isLessThanOrEqualTo: endDate)
          .orderBy('pickup_date', descending: true)
          .get();

      double total = 0.0;
      List<Map<String, dynamic>> activities = [];

      // Process all successful pickups
      for (var doc in successfulPickupsQuery.docs) {
        final data = doc.data();
        double pickupWeight = 0.0;

        // Calculate total weight from waste_weights map
        if (data['waste_weights'] != null) {
          final wasteWeights = data['waste_weights'] as Map<String, dynamic>;
          wasteWeights.forEach((type, weight) {
            if (weight is num) {
              pickupWeight += weight.toDouble();
            }
          });
        }

        // Add household waste weights
        if (data['household_waste_weights'] != null) {
          final householdWeights =
          data['household_waste_weights'] as Map<String, dynamic>;
          householdWeights.forEach((type, weight) {
            if (weight is num) {
              pickupWeight += weight.toDouble();
            }
          });
        }

        // Add commercial waste weights
        if (data['commercial_waste_weights'] != null) {
          final commercialWeights =
          data['commercial_waste_weights'] as Map<String, dynamic>;
          commercialWeights.forEach((type, weight) {
            if (weight is num) {
              pickupWeight += weight.toDouble();
            }
          });
        }

        // Add scrap weights
        if (data['scrap_weights'] != null) {
          final scrapWeights = data['scrap_weights'] as Map<String, dynamic>;
          scrapWeights.forEach((type, weight) {
            if (weight is num) {
              pickupWeight += weight.toDouble();
            }
          });
        }

        total += pickupWeight;

        // Determine pickup type and icon
        IconData activityIcon;
        String activityTitle;

        if (data['type'] == 'special_day') {
          activityIcon = Icons.local_florist;
          activityTitle = 'Special Day Collection';
        } else {
          activityIcon = Icons.delete_outline;
          activityTitle = 'Monthly Subscription Pickup';
        }

        // Format date for display
        DateTime pickupDate;
        if (data['pickup_date'] is Timestamp) {
          pickupDate = (data['pickup_date'] as Timestamp).toDate();
        } else {
          pickupDate = DateTime.now(); // Fallback
        }

        activities.add({
          'icon': activityIcon,
          'title': activityTitle,
          'points': '+${pickupWeight.toStringAsFixed(1)} kg',
          'date': _formatDate(pickupDate),
          'raw_date': pickupDate, // For sorting
        });
      }

      // Sort activities by date (newest first)
      activities.sort((a, b) => b['raw_date'].compareTo(a['raw_date']));

      setState(() {
        totalWasteCollected = total;
        recentActivities = activities;
        isLoading = false;
      });

      // Check if goal is completed
      final goal = isMonthlyView ? monthlyGoal : yearlyGoal;

      if (total >= goal) {
        setState(() {
          isGoalCompleted = true;
        });

        // Check if we should create a notification
        final periodType = isMonthlyView ? 'Monthly' : 'Yearly';
        final period = isMonthlyView ? currentMonth : currentYear;
        final prefs = await SharedPreferences.getInstance();
        final notificationKey =
            '${periodType.toLowerCase()}_goal_notification_${userId}_${period}_${currentYear}';

        // Only create notification if we haven't done so yet
        if (!(prefs.getBool(notificationKey) ?? false)) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'user_id': userId,
            'message':
            'Congratulations! You have completed your $periodType Goal for $period. Check it out!',
            'created_at': Timestamp.now(),
            'read': false,
            'type': 'goal_completed'
          });

          // Mark that we've created the notification
          await prefs.setBool(notificationKey, true);
        }
      } else {
        setState(() {
          isGoalCompleted = false;
        });
      }
    } catch (e) {
      print('Error loading pickup data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Future<void> _markGoalAsRedeemed() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (isMonthlyView) {
      final key =
          'monthly_goal_redeemed_${userId}_${currentMonth}_${currentYear}';
      await prefs.setBool(key, true);
    } else {
      final key = 'yearly_goal_redeemed_${userId}_${currentYear}';
      await prefs.setBool(key, true);
    }

    setState(() {
      isGoalRedeemed = true;
    });
  }

  void _showRedemptionForm() {
    showDialog(
      context: context,
      builder: (context) => AddressScreen(
        onAddressSelected: (addressData) async {
          try {
            final userId = FirebaseAuth.instance.currentUser?.uid;
            if (userId == null) throw Exception('User not authenticated');

            // Store redemption details in Firestore
            await FirebaseFirestore.instance
                .collection('redeemed_rewards')
                .add({
              'user_id': userId,
              'reward_type': isMonthlyView ? 'monthly' : 'yearly',
              'period': isMonthlyView ? currentMonth : currentYear,
              'year': currentYear,
              'name': addressData['name'],
              'mobile': addressData['mobile'],
              'address': addressData['address'],
              'redeemed_at': Timestamp.now(),
              'status': 'pending',
              'waste_collected': totalWasteCollected,
            });

            // Create delivery notification
            await FirebaseFirestore.instance.collection('notifications').add({
              'user_id': userId,
              'message':
              'Your reward has been successfully redeemed! Your reward will be delivered to you in 2-3 days.',
              'created_at': Timestamp.now(),
              'read': false,
              'type': 'reward_redemption'
            });

            await _markGoalAsRedeemed();

            Navigator.pop(context);

            // Show success message
            if (mounted) {
              CustomSnackbar.showSuccess(
                context: context,
                message:
                'Your reward has been redeemed successfully! It will be delivered in 2-3 days.',
              );
            }
          } catch (e) {
            print('Error redeeming reward: $e');
            if (mounted) {
              CustomSnackbar.showError(
                context: context,
                message: 'Failed to redeem reward. Please try again.',
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white)
              .animate()
              .fade()
              .scale(delay: 200.ms),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Your Rewards',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildToggleBar(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRewardsSummary(),
                    const SizedBox(height: 24),
                    _buildRecentActivities(),
                  ]
                      .animate(interval: 200.ms)
                      .fadeIn()
                      .slideY(begin: 0.2, end: 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBar() {
    return Container(
      color: primaryColor,
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
                  if (!isMonthlyView) {
                    setState(() {
                      isMonthlyView = true;
                    });
                    _loadData();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isMonthlyView ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Monthly Reward',
                      style: GoogleFonts.poppins(
                        color: isMonthlyView ? primaryColor : Colors.white,
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
                  if (isMonthlyView) {
                    setState(() {
                      isMonthlyView = false;
                    });
                    _loadData();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !isMonthlyView ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Yearly Reward',
                      style: GoogleFonts.poppins(
                        color: !isMonthlyView ? primaryColor : Colors.white,
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

  Widget _buildRewardsSummary() {
    final goal = isMonthlyView ? monthlyGoal : yearlyGoal;
    final period = isMonthlyView ? currentMonth : currentYear;
    final periodType = isMonthlyView ? 'Monthly' : 'Yearly';
    final isComplete = totalWasteCollected >= goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$period Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Goal ${goal.toInt()}kg',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isComplete ? Icons.celebration : Icons.eco,
                  color: primaryColor,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value:
            totalWasteCollected / goal > 1 ? 1 : totalWasteCollected / goal,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          Text(
            isComplete
                ? 'Congratulations! You\'ve reached your goal!'
                : '${(goal - totalWasteCollected).toStringAsFixed(1)} kg more until next reward',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isComplete ? primaryColor : Colors.grey[600],
              fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWasteStat('$periodType Goal', '$goal kg'),
              _buildWasteStat(
                  'Collected', '${totalWasteCollected.toStringAsFixed(1)} kg'),
              _buildWasteStat('Progress',
                  '${((totalWasteCollected / goal) * 100).toStringAsFixed(0)}%'),
            ],
          ),

          // Show redeem button only if goal is completed and not yet redeemed
          if (isComplete && !isGoalRedeemed) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showRedemptionForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: Size(double.infinity, 0), // full width
              ),
              icon: Icon(Icons.card_giftcard, color: Colors.white),
              label: Text(
                'Redeem Your Reward',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).scale(),
          ],

          // Show redeemed status if already redeemed
          if (isComplete && isGoalRedeemed) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Reward Redeemed',
                    style: GoogleFonts.poppins(
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),
          ],
        ],
      ),
    );
  }

  Widget _buildWasteStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    final periodType = isMonthlyView ? 'Monthly' : 'Yearly';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$periodType Activities',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (recentActivities.isEmpty)
          Center(
            child: Text(
              'No recent activities',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          )
        else
          ...recentActivities.map(
                (activity) => _buildActivityItem(
              icon: activity['icon'],
              title: activity['title'],
              points: activity['points'],
              date: activity['date'],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String points,
    required String date,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  date,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: GoogleFonts.poppins(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// AddressScreen Widget
class AddressScreen extends StatefulWidget {
  final Function(Map<String, String>) onAddressSelected;

  const AddressScreen({Key? key, required this.onAddressSelected})
      : super(key: key);

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _roadController = TextEditingController();
  String? _city;
  String? _state;
  final Color primaryGreen = const Color(0xFF2E7D32);
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _pincodeController.dispose();
    _houseController.dispose();
    _roadController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationDetails(String pincode) async {
    if (pincode.length != 6) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(Uri.parse("http://www.postalpincode.in/api/pincode/$pincode"));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['Status'] == 'Success') {
          final postOffice = jsonResponse['PostOffice'][0];
          setState(() {
            _city = postOffice['District'];
            _state = postOffice['State'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _city = null;
            _state = null;
            _isLoading = false;
          });
          if (mounted) {
            CustomSnackbar.showError(
              context: context,
              message: 'Invalid pincode.',
            );
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Failed to load location details');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomSnackbar.showError(
          context: context,
          message: 'Error fetching location: ${e.toString()}',
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryGreen, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _submitAddress() {
    if (_formKey.currentState!.validate()) {
      String address =
          '${_houseController.text}, ${_roadController.text}, ${_city ?? ''}, ${_state ?? ''}, ${_pincodeController.text}';
      Map<String, String> addressData = {
        'name': _nameController.text,
        'mobile': _mobileController.text,
        'address': address,
      };
      widget.onAddressSelected(addressData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Delivery Address',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Full Name'),
                  style: GoogleFonts.poppins(),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: _buildInputDecoration('Mobile Number'),
                  style: GoogleFonts.poppins(),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value?.isEmpty ?? true)
                      return 'Please enter mobile number';
                    if (value!.length != 10)
                      return 'Please enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _houseController,
                  decoration: _buildInputDecoration('House no / Building Name'),
                  style: GoogleFonts.poppins(),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter building name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roadController,
                  decoration:
                  _buildInputDecoration('Road Name / Area / Colony'),
                  style: GoogleFonts.poppins(),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter road name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pincodeController,
                  decoration: _buildInputDecoration('Pincode'),
                  style: GoogleFonts.poppins(),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter pincode';
                    if (value!.length != 6)
                      return 'Please enter a valid 6-digit pincode';
                    return null;
                  },
                  onChanged: (value) {
                    if (value.length == 6) {
                      _fetchLocationDetails(value);
                    } else {
                      setState(() {
                        _city = null;
                        _state = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          TextFormField(
                            decoration: _buildInputDecoration('City'),
                            controller: TextEditingController(text: _city),
                            style: GoogleFonts.poppins(),
                            readOnly: true,
                            enabled: !_isLoading,
                            validator: (value) =>
                            _city == null || _city!.isEmpty
                                ? 'Please enter valid pincode to get city'
                                : null,
                          ),
                          if (_isLoading)
                            Positioned(
                              right: 10,
                              top: 15,
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryGreen),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: _buildInputDecoration('State'),
                        controller: TextEditingController(text: _state),
                        style: GoogleFonts.poppins(),
                        readOnly: true,
                        enabled: !_isLoading,
                        validator: (value) => _state == null || _state!.isEmpty
                            ? 'Please enter valid pincode to get state'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _submitAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Save Address',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
