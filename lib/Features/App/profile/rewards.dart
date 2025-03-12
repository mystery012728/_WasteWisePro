import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    } else {
      await _loadYearlyData();
    }
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
          final householdWeights = data['household_waste_weights'] as Map<String, dynamic>;
          householdWeights.forEach((type, weight) {
            if (weight is num) {
              pickupWeight += weight.toDouble();
            }
          });
        }

        // Add commercial waste weights
        if (data['commercial_waste_weights'] != null) {
          final commercialWeights = data['commercial_waste_weights'] as Map<String, dynamic>;
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
                  ].animate(interval: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
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
                  Icons.eco,
                  color: primaryColor,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: totalWasteCollected / goal,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          Text(
            '${(goal - totalWasteCollected).toStringAsFixed(1)} kg more until next reward',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWasteStat('$periodType Goal', '$goal kg'),
              _buildWasteStat('Collected', '${totalWasteCollected.toStringAsFixed(1)} kg'),
              _buildWasteStat('Progress', '${((totalWasteCollected/goal)*100).toStringAsFixed(0)}%'),
            ],
          ),
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
          ...recentActivities.map((activity) =>
              _buildActivityItem(
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

