import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// Constants for SharedPreferences keys
const String LAST_SCAN_KEY = 'last_scan';
const String FLASH_STATE_KEY = 'flash_state';
const String SCAN_HISTORY_KEY = 'scan_history';
const String SCANNING_ENABLED_KEY = 'scanning_enabled';

// Result Page Widget
class ResultPage extends StatefulWidget {
  final String scannedData;

  const ResultPage({Key? key, required this.scannedData}) : super(key: key);

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final Color primaryGreen = const Color(0xFF2E7D32);
  bool isLoading = true;
  Map<String, dynamic>? subscriptionData;
  List<Map<String, dynamic>> specialDaysList = [];
  int currentSpecialDayIndex = 0;
  bool isSubscriptionCancelled = false;
  bool isPickupMissed = false;
  Map<String, TextEditingController> weightControllers = {};
  final PageController _specialDaysPageController = PageController();

  @override
  void initState() {
    super.initState();
    _disableScanning();
    _fetchPickupDetails();

    // Initialize ScreenUtil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenUtil.instance.init(context);
    });
  }

  @override
  void dispose() {
    weightControllers.forEach((_, controller) => controller.dispose());
    _specialDaysPageController.dispose();
    _enableScanning(); // Re-enable scanning when leaving the page
    super.dispose();
  }

  Future<void> _disableScanning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SCANNING_ENABLED_KEY, false);
  }

  Future<void> _enableScanning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SCANNING_ENABLED_KEY, true);
  }

  bool _isWithinPickupWindow(String pickupTime) {
    try {
      // Parse pickup time (assuming format like "09:00 AM")
      final format = DateFormat("hh:mm a");
      final now = DateTime.now();
      final pickupDateTime = format.parse(pickupTime);

      // Create DateTime for pickup time today
      final scheduledPickup = DateTime(
        now.year,
        now.month,
        now.day,
        pickupDateTime.hour,
        pickupDateTime.minute,
      );

      // Add 30 minutes to pickup time
      final pickupWindowEnd = scheduledPickup.add(Duration(minutes: 30));

      // Check if current time is before window end and after/equal to pickup time
      return now.isBefore(pickupWindowEnd) &&
          now.isAfter(scheduledPickup.subtract(Duration(minutes: 1)));
    } catch (e) {
      print('Error parsing pickup time: $e');
      return false;
    }
  }

  Future<void> _addToMissedPickups() async {
    try {
      // Add to missed pickups collection
      await FirebaseFirestore.instance.collection('missed_pickups').add({
        'subscription_id': subscriptionData!['id'],
        'customer_id': subscriptionData!['customer_id'],
        'scheduled_date': DateTime.now(),
        'scheduled_time': subscriptionData!['pickup_time'],
        'subscription_type': subscriptionData!['subscription_type'],
        'missed_at': DateTime.now(),
        'status': 'missed'
      });

      // Update UI to show missed status
      setState(() {
        isPickupMissed = true;
      });
    } catch (e) {
      print('Error adding to missed pickups: $e');
    }
  }

  Future<void> _fetchPickupDetails() async {
    try {
      // Fetch subscription details
      final subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('subscription_details')
          .where('status', isEqualTo: 'active')
          .get();

      // Fetch special day details
      final specialDaySnapshot = await FirebaseFirestore.instance
          .collection('special_day_details')
          .where('status', isEqualTo: 'active')
          .get();

      // Check if today's pickup is cancelled
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (subscriptionSnapshot.docs.isNotEmpty) {
        final subscriptionDoc = subscriptionSnapshot.docs.first;
        final subscriptionId = subscriptionDoc.id;
        final data = subscriptionDoc.data();
        data['id'] = subscriptionId;

        // Initialize weight controllers for each waste type
        if (data['household_waste_types'] != null) {
          (data['household_waste_types'] as List<dynamic>).forEach((type) {
            weightControllers[type] = TextEditingController();
          });
        }
        if (data['commercial_waste_types'] != null) {
          (data['commercial_waste_types'] as List<dynamic>).forEach((type) {
            weightControllers[type] = TextEditingController();
          });
        }

        final cancelledPickups = await FirebaseFirestore.instance
            .collection('cancelled_pickups')
            .where('subscription_id', isEqualTo: subscriptionId)
            .where('date', isEqualTo: Timestamp.fromDate(today))
            .get();

        setState(() {
          subscriptionData = data;
          isSubscriptionCancelled = cancelledPickups.docs.isNotEmpty;

          if (!isSubscriptionCancelled && data['pickup_time'] != null) {
            isPickupMissed = !_isWithinPickupWindow(data['pickup_time']);
            if (isPickupMissed) {
              _addToMissedPickups();
            }
          }
        });
      }

      if (specialDaySnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> specialDays = [];

        for (var doc in specialDaySnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;

          // Initialize weight controllers for special day waste types
          if (data['type'] == 'waste') {
            if (data['household_waste'] != null) {
              (data['household_waste'] as List<dynamic>).forEach((type) {
                weightControllers['household_$type'] = TextEditingController();
              });
            }
            if (data['commercial_waste'] != null) {
              (data['commercial_waste'] as List<dynamic>).forEach((type) {
                weightControllers['commercial_$type'] = TextEditingController();
              });
            }
          } else if (data['type'] == 'scrap') {
            if (data['scrap_types'] != null) {
              (data['scrap_types'] as List<dynamic>).forEach((type) {
                weightControllers['scrap_$type'] = TextEditingController();
              });
            }
          }

          specialDays.add(data);
        }

        setState(() {
          specialDaysList = specialDays;
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching pickup details: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _startMissedPickupTimer() {
    // Simple timer to check for missed pickups after 30 minutes
    Future.delayed(Duration(minutes: 30), () {
      if (mounted) {
        _checkForMissedPickups();
      }
    });
  }

  Future<void> _checkForMissedPickups() async {
    // Check subscription pickup
    if (subscriptionData != null &&
        !isSubscriptionCancelled &&
        !isPickupMissed) {
      // If pickup time has passed and not confirmed, mark as missed
      if (!_isWithinPickupWindow(subscriptionData!['pickup_time'])) {
        await _addToMissedPickups();
        setState(() {
          isPickupMissed = true;
        });
      }
    }

    // Check special day pickups
    for (var specialDay in specialDaysList) {
      final pickupTime = specialDay['pickup_time'] as String;
      if (!_isWithinPickupWindow(pickupTime)) {
        // Add to missed pickups collection
        await FirebaseFirestore.instance.collection('missed_pickups').add({
          'special_day_id': specialDay['id'],
          'customer_id': specialDay['userId'],
          'scheduled_date': specialDay['pickup_date'],
          'scheduled_time': specialDay['pickup_time'],
          'type': 'special_day',
          'waste_type': specialDay['type'],
          'missed_at': Timestamp.now(),
          'status': 'missed'
        });

        // Update special day status to inactive
        await FirebaseFirestore.instance
            .collection('special_day_details')
            .doc(specialDay['id'])
            .update({'status': 'inactive', 'missed_at': Timestamp.now()});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pickup Confirmation',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        backgroundColor: primaryGreen,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () async {
            // Re-enable scanning when going back
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(SCANNING_ENABLED_KEY, true);
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subscriptionData != null) _buildSubscriptionCard(),
                        if (specialDaysList.isNotEmpty) ...[
                          SizedBox(height: 20.h),
                          _buildSpecialDaysSection(),
                        ],
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30.r),
          bottomRight: Radius.circular(30.r),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_scanner,
            color: Colors.white,
            size: 48.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            'QR Code Scanned Successfully',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            'Verification Code: ${widget.scannedData}',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    if (subscriptionData == null) return SizedBox.shrink();

    final startDate = (subscriptionData!['start_date'] as Timestamp).toDate();
    final endDate = (subscriptionData!['end_date'] as Timestamp).toDate();
    final pickupTime = subscriptionData!['pickup_time'] as String;
    final subscriptionType = subscriptionData!['subscription_type'] as String;
    final now = DateTime.now();

    List<String> householdWasteTypes =
        List<String>.from(subscriptionData!['household_waste_types'] ?? []);
    List<String> commercialWasteTypes =
        List<String>.from(subscriptionData!['commercial_waste_types'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'Subscription Details',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.repeat, color: primaryGreen, size: 24.sp),
            ),
            title: Text(
              '$subscriptionType Subscription',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16.sp),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                Text(
                  'Today\'s Date: ${DateFormat('MMM d, yyyy').format(now)}',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  'Pickup Time: $pickupTime',
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 14.sp),
                ),
                Text(
                  'Valid: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}',
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 14.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  subscriptionData!['pickup_address'],
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 14.sp),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                if (isSubscriptionCancelled)
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 24.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Today\'s pickup is cancelled. Service will resume tomorrow.',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isPickupMissed)
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 24.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Today\'s pickup window has expired. Pickup was scheduled for $pickupTime.',
                            style: GoogleFonts.poppins(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (!isSubscriptionCancelled && !isPickupMissed) ...[
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (householdWasteTypes.isNotEmpty) ...[
                            Text(
                              'Household Waste',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: primaryGreen,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ...householdWasteTypes.map((type) => Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: TextField(
                                    controller: weightControllers[type],
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Enter $type weight (kg)',
                                      hintText: 'e.g. 5.5',
                                      border: OutlineInputBorder(
                                        gapPadding: 5.5,
                                        borderRadius:
                                            BorderRadius.circular(10.r),
                                      ),
                                      prefixIcon: Icon(Icons.scale,
                                          color: primaryGreen, size: 20.sp),
                                    ),
                                  ),
                                )),
                          ],
                          if (commercialWasteTypes.isNotEmpty) ...[
                            SizedBox(height: 16.h),
                            Text(
                              'Commercial Waste',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: primaryGreen,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ...commercialWasteTypes.map((type) => Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: TextField(
                                    controller: weightControllers[type],
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Enter $type weight (kg)',
                                      hintText: 'e.g. 5.5',
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10.r),
                                      ),
                                      prefixIcon: Icon(Icons.scale,
                                          color: primaryGreen, size: 20.sp),
                                    ),
                                  ),
                                )),
                          ],
                          SizedBox(height: 16.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                Map<String, double> weights = {};
                                // Collect weights without validation
                                weightControllers.forEach((type, controller) {
                                  if (controller.text.isNotEmpty) {
                                    weights[type] =
                                        double.parse(controller.text);
                                  }
                                });

                                try {
                                  // Add to successful pickups collection
                                  await FirebaseFirestore.instance
                                      .collection('successful_pickups')
                                      .add({
                                    'subscription_id': subscriptionData!['id'],
                                    'customer_id':
                                        subscriptionData!['customer_id'],
                                    'pickup_date': Timestamp.now(),
                                    'scheduled_time':
                                        subscriptionData!['pickup_time'],
                                    'subscription_type':
                                        subscriptionData!['subscription_type'],
                                    'waste_weights': weights,
                                    'household_waste_types':
                                        householdWasteTypes,
                                    'commercial_waste_types':
                                        commercialWasteTypes,
                                    'status': 'completed'
                                  });

                                  // Add to upcoming pickups collection for next pickup
                                  final nextPickupDate =
                                      DateTime.now().add(Duration(days: 1));
                                  await FirebaseFirestore.instance
                                      .collection('upcoming_pickups')
                                      .add({
                                    'subscription_id': subscriptionData!['id'],
                                    'customer_id':
                                        subscriptionData!['customer_id'],
                                    'pickup_date':
                                        Timestamp.fromDate(nextPickupDate),
                                    'scheduled_time':
                                        subscriptionData!['pickup_time'],
                                    'subscription_type':
                                        subscriptionData!['subscription_type'],
                                    'pickup_address':
                                        subscriptionData!['pickup_address'],
                                    'household_waste_types':
                                        householdWasteTypes,
                                    'commercial_waste_types':
                                        commercialWasteTypes,
                                    'status': 'pending',
                                    'type': 'subscription',
                                    'created_at': Timestamp.now()
                                  });

                                  // Pickup confirmed successfully

                                  if (mounted) {
                                    CustomSnackbar.showSuccess(
                                      context: context,
                                      message: 'Pickup confirmed successfully!',
                                    );
                                  }

                                  // Re-enable scanning
                                  await _enableScanning();
                                  Navigator.pop(context);
                                } catch (e) {
                                  print('Error confirming pickup: $e');
                                  if (mounted) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      message:
                                          'Failed to confirm pickup. Please try again.',
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              child: Text(
                                'Confirm Subscription Pickup',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialDaysSection() {
    if (specialDaysList.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Special Day Pickups',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            if (specialDaysList.length > 1)
              Row(
                children: [
                  Text(
                    '${currentSpecialDayIndex + 1}/${specialDaysList.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios, size: 16.sp),
                          onPressed: currentSpecialDayIndex > 0
                              ? () {
                                  _specialDaysPageController.previousPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          color: currentSpecialDayIndex > 0
                              ? primaryGreen
                              : Colors.grey[400],
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios, size: 16.sp),
                          onPressed: currentSpecialDayIndex <
                                  specialDaysList.length - 1
                              ? () {
                                  _specialDaysPageController.nextPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          color: currentSpecialDayIndex <
                                  specialDaysList.length - 1
                              ? primaryGreen
                              : Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        SizedBox(height: 10.h),
        Container(
          height: 450.h, // Fixed height for the PageView
          child: PageView.builder(
            controller: _specialDaysPageController,
            itemCount: specialDaysList.length,
            onPageChanged: (index) {
              setState(() {
                currentSpecialDayIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildSpecialDayCard(specialDaysList[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialDayCard(Map<String, dynamic> specialDayData) {
    final pickupDate = (specialDayData['pickup_date'] as Timestamp).toDate();
    final pickupTime = specialDayData['pickup_time'] as String;
    final type = specialDayData['type'] as String;

    // Check if we're within the pickup window
    final isWithinPickupWindow = _isWithinPickupWindow(pickupTime);

    // Calculate total scrap weight and price for scrap pickups
    double totalScrapWeight = 0.0;
    double totalScrapPrice = 0.0;

    if (type == 'scrap' && specialDayData['scrap_weights'] != null) {
      final scrapWeights =
          specialDayData['scrap_weights'] as Map<String, dynamic>;

      // Use stored total values if available
      if (specialDayData['total_scrap_weight'] != null) {
        totalScrapWeight =
            (specialDayData['total_scrap_weight'] as num).toDouble();
      } else {
        // Calculate from individual weights
        scrapWeights.forEach((type, weight) {
          if (weight is num) {
            totalScrapWeight += weight.toDouble();
          }
        });
      }

      if (specialDayData['total_scrap_price'] != null) {
        totalScrapPrice =
            (specialDayData['total_scrap_price'] as num).toDouble();
      } else {
        // Calculate from individual weights and prices
        scrapWeights.forEach((type, weight) {
          if (weight is num) {
            double pricePerKg = 0.0;
            switch (type) {
              case 'News Paper':
                pricePerKg = 15;
                break;
              case 'Office Paper(A3/A4)':
                pricePerKg = 15;
                break;
              case 'Books':
                pricePerKg = 12;
                break;
              case 'Cardboard':
                pricePerKg = 8;
                break;
              case 'Plastic':
                pricePerKg = 10;
                break;
            }
            totalScrapPrice += weight.toDouble() * pricePerKg;
          }
        });
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'Special Day Pickup',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                type == 'waste' ? Icons.delete : Icons.recycling,
                color: primaryGreen,
                size: 24.sp,
              ),
            ),
            title: Text(
              'Special ${type.capitalize()} Pickup',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16.sp),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                Text(
                  'Date: ${DateFormat('MMM d, yyyy').format(pickupDate)}',
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 14.sp),
                ),
                Text(
                  'Time: $pickupTime',
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 14.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  specialDayData['pickup_address'],
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 14.sp),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'waste') ...[
                    // Household waste section
                    if (specialDayData['household_waste'] != null &&
                        (specialDayData['household_waste'] as List)
                            .isNotEmpty) ...[
                      Text(
                        'Household Waste',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      ...(specialDayData['household_waste'] as List)
                          .map((type) {
                        final controllerKey = 'household_$type';
                        final weight = specialDayData['household_waste_weights']
                                ?[type] ??
                            0.0;

                        // Initialize controller if it doesn't exist
                        weightControllers.putIfAbsent(
                            controllerKey, () => TextEditingController());

                        // Set text value if weight is greater than 0
                        if (weight > 0) {
                          weightControllers[controllerKey]?.text =
                              weight.toString();
                        }

                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: TextField(
                            controller: weightControllers[controllerKey],
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Enter $type weight (kg)',
                              hintText: 'e.g. 5.5',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              prefixIcon: Icon(Icons.scale,
                                  color: primaryGreen, size: 20.sp),
                            ),
                          ),
                        );
                      }).toList(),
                    ],

                    // Commercial waste section
                    if (specialDayData['commercial_waste'] != null &&
                        (specialDayData['commercial_waste'] as List) != null &&
                        (specialDayData['commercial_waste'] as List)
                            .isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      Text(
                        'Commercial Waste',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      ...(specialDayData['commercial_waste'] as List)
                          .map((type) {
                        final controllerKey = 'commercial_$type';
                        final weight =
                            specialDayData['commercial_waste_weights']?[type] ??
                                0.0;

                        // Initialize controller if it doesn't exist
                        weightControllers.putIfAbsent(
                            controllerKey, () => TextEditingController());

                        // Set text value if weight is greater than 0
                        if (weight > 0) {
                          weightControllers[controllerKey]?.text =
                              weight.toString();
                        }

                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: TextField(
                            controller: weightControllers[controllerKey],
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Enter $type weight (kg)',
                              hintText: 'e.g. 5.5',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              prefixIcon: Icon(Icons.scale,
                                  color: primaryGreen, size: 20.sp),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ] else if (type == 'scrap') ...[
                    // Scrap section
                    if (specialDayData['scrap_types'] != null &&
                        (specialDayData['scrap_types'] as List).isNotEmpty) ...[
                      Text(
                        'Scrap Items',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      ...(specialDayData['scrap_types'] as List).map((type) {
                        final controllerKey = 'scrap_$type';
                        final weight =
                            specialDayData['scrap_weights']?[type] ?? 0.0;

                        // Initialize controller if it doesn't exist
                        weightControllers.putIfAbsent(
                            controllerKey, () => TextEditingController());

                        // Set text value if weight is greater than 0
                        if (weight > 0) {
                          weightControllers[controllerKey]?.text =
                              weight.toString();
                        }

                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: TextField(
                            controller: weightControllers[controllerKey],
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Enter $type weight (kg)',
                              hintText: 'e.g. 5.5',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              prefixIcon: Icon(Icons.scale,
                                  color: primaryGreen, size: 20.sp),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],

                  SizedBox(height: 16.h),
                  // Only show confirm button if within pickup window
                  if (isWithinPickupWindow)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Collect weights for the current special day
                          Map<String, double> householdWeights = {};
                          Map<String, double> commercialWeights = {};
                          Map<String, double> scrapWeights = {};
                          double totalScrapWeight = 0.0;
                          double totalScrapPrice = 0.0;

                          // Process household waste weights
                          if (specialDayData['household_waste'] != null) {
                            for (var type
                                in specialDayData['household_waste']) {
                              final controllerKey = 'household_$type';
                              if (weightControllers[controllerKey]
                                      ?.text
                                      .isNotEmpty ??
                                  false) {
                                householdWeights[type] = double.parse(
                                    weightControllers[controllerKey]!.text);
                              }
                            }
                          }

                          // Process commercial waste weights
                          if (specialDayData['commercial_waste'] != null) {
                            for (var type
                                in specialDayData['commercial_waste']) {
                              final controllerKey = 'commercial_$type';
                              if (weightControllers[controllerKey]
                                      ?.text
                                      .isNotEmpty ??
                                  false) {
                                commercialWeights[type] = double.parse(
                                    weightControllers[controllerKey]!.text);
                              }
                            }
                          }

                          // Process scrap weights and calculate total price
                          if (specialDayData['scrap_types'] != null) {
                            for (var type in specialDayData['scrap_types']) {
                              final controllerKey = 'scrap_$type';
                              if (weightControllers[controllerKey]
                                      ?.text
                                      .isNotEmpty ??
                                  false) {
                                double weight = double.parse(
                                    weightControllers[controllerKey]!.text);
                                scrapWeights[type] = weight;
                                totalScrapWeight += weight;

                                // Calculate price based on scrap type
                                double pricePerKg = 0.0;
                                switch (type) {
                                  case 'News Paper':
                                    pricePerKg = 15;
                                    break;
                                  case 'Office Paper(A3/A4)':
                                    pricePerKg = 15;
                                    break;
                                  case 'Books':
                                    pricePerKg = 12;
                                    break;
                                  case 'Cardboard':
                                    pricePerKg = 8;
                                    break;
                                  case 'Plastic':
                                    pricePerKg = 10;
                                    break;
                                }
                                totalScrapPrice += weight * pricePerKg;
                              }
                            }
                          }

                          try {
                            // Add to successful pickups collection
                            await FirebaseFirestore.instance
                                .collection('successful_pickups')
                                .add({
                              'special_day_id': specialDayData['id'],
                              'customer_id': specialDayData['userId'],
                              'pickup_date': Timestamp.now(),
                              'scheduled_time': specialDayData['pickup_time'],
                              'type': 'special_day',
                              'waste_type': specialDayData['type'],
                              'household_waste':
                                  specialDayData['household_waste'],
                              'commercial_waste':
                                  specialDayData['commercial_waste'],
                              'scrap_types': specialDayData['scrap_types'],
                              'household_waste_weights': householdWeights,
                              'commercial_waste_weights': commercialWeights,
                              'scrap_weights': scrapWeights,
                              'total_scrap_weight':
                                  type == 'scrap' ? totalScrapWeight : null,
                              'total_scrap_price':
                                  type == 'scrap' ? totalScrapPrice : null,
                              'status': 'completed',
                              'completed_at': Timestamp.now()
                            });

                            // Update special day status to inactive
                            await FirebaseFirestore.instance
                                .collection('special_day_details')
                                .doc(specialDayData['id'])
                                .update({
                              'status': 'inactive',
                              'completed_at': Timestamp.now()
                            });

                            if (mounted) {
                              CustomSnackbar.showSuccess(
                                context: context,
                                message:
                                    'Special day pickup confirmed successfully!',
                              );
                            }

                            // Re-enable scanning
                            await _enableScanning();
                            Navigator.pop(context);
                          } catch (e) {
                            print('Error confirming special day pickup: $e');
                            if (mounted) {
                              CustomSnackbar.showError(
                                context: context,
                                message:
                                    'Failed to confirm pickup. Please try again.',
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: Text(
                          type == 'scrap'
                              ? 'Confirm Scrap Pickup - ₹${totalScrapPrice.toStringAsFixed(2)}'
                              : 'Confirm Special Day Pickup',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              color: Colors.orange, size: 24.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Confirm button will be available at the scheduled pickup time: $pickupTime',
                              style: GoogleFonts.poppins(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Scanner Overlay Painter remains the same
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double borderLength = 40;
    final double borderWidth = 4;
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw corner borders
    // Top left corner
    canvas.drawLine(Offset.zero, Offset(borderLength, 0), borderPaint);
    canvas.drawLine(Offset.zero, Offset(0, borderLength), borderPaint);

    // Top right corner
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - borderLength, 0),
      borderPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, borderLength),
      borderPaint,
    );

    // Bottom left corner
    canvas.drawLine(
      Offset(0, size.height),
      Offset(borderLength, size.height),
      borderPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - borderLength),
      borderPaint,
    );

    // Bottom right corner
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - borderLength, size.height),
      borderPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool isFlashOn = false;
  late MobileScannerController cameraController;
  String? lastScannedValue;
  final Color primaryGreen = const Color(0xFF2E7D32);
  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  late SharedPreferences prefs;
  List<String> scanHistory = [];
  bool isScanningEnabled = true;
  bool _isStarting = false; // Track if camera is starting

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController();
    _initPreferences();
    // Add listener for scanning status changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScanningStatus();
      // Initialize ScreenUtil
      ScreenUtil.instance.init(context);
    });
  }

  Future<void> _checkScanningStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final scanningEnabled = prefs.getBool(SCANNING_ENABLED_KEY) ?? true;

    if (mounted) {
      // Always update the scanning state when returning to the scanner
      setState(() {
        isScanningEnabled = scanningEnabled;
      });

      // Ensure scanning is enabled when returning to scanner
      if (!isScanningEnabled) {
        // Re-enable scanning
        setState(() {
          isScanningEnabled = true;
        });
        await prefs.setBool(SCANNING_ENABLED_KEY, true);
      }

      // Reset camera controller if needed
      if (scanningEnabled && !_isStarting) {
        // Restart camera if it's not already starting
        setState(() {
          _isStarting = true;
        });
        try {
          await cameraController.start();
        } finally {
          if (mounted) {
            setState(() {
              _isStarting = false;
            });
          }
        }
      }
    }
  }

  Future<void> _initPreferences() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      isFlashOn = prefs.getBool(FLASH_STATE_KEY) ?? false;
      lastScannedValue = prefs.getString(LAST_SCAN_KEY);
      scanHistory = prefs.getStringList(SCAN_HISTORY_KEY) ?? [];
      isScanningEnabled = prefs.getBool(SCANNING_ENABLED_KEY) ?? true;

      if (isFlashOn) {
        cameraController.toggleTorch();
      }
    });
  }

  Future<void> _saveToHistory(String scannedData) async {
    // Save last scan
    await prefs.setString(LAST_SCAN_KEY, scannedData);

    // Update scan history (keep last 10 scans)
    scanHistory.insert(0, '${DateTime.now().toIso8601String()} - $scannedData');
    if (scanHistory.length > 10) {
      scanHistory = scanHistory.sublist(0, 10);
    }
    await prefs.setStringList(SCAN_HISTORY_KEY, scanHistory);
  }

  @override
  void dispose() {
    cameraController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!isScanningEnabled) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                lastScannedValue = barcode.rawValue;
                _saveToHistory(barcode.rawValue ?? 'No data found');

                // Disable scanning until user returns
                setState(() {
                  isScanningEnabled = false;
                });
                prefs.setBool(SCANNING_ENABLED_KEY, false);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(
                      scannedData: barcode.rawValue ?? 'No data found',
                    ),
                  ),
                ).then((_) {
                  // Check if scanning should be re-enabled
                  _checkScanningStatus();

                  // Ensure camera is restarted
                  if (mounted) {
                    setState(() {
                      isScanningEnabled = true;
                    });
                    // Restart camera controller
                    cameraController.start();
                  }
                });
                break;
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30.r),
                      bottomRight: Radius.circular(30.r),
                    ),
                  ),
                  padding: EdgeInsets.all(20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scan Pickup Code',
                        style: GoogleFonts.poppins(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                        onPressed: () async {
                          await cameraController.toggleTorch();
                          setState(() {
                            isFlashOn = !isFlashOn;
                          });
                          await prefs.setBool(FLASH_STATE_KEY, isFlashOn);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.width * 0.8,
                          child: CustomPaint(
                            painter: ScannerOverlayPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            controller: _dragController,
            initialChildSize: 0.2,
            minChildSize: 0.1,
            maxChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.r),
                    topRight: Radius.circular(30.r),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      SizedBox(height: 12.h),
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          children: [
                            Text(
                              'Waste Pickup Verification',
                              style: GoogleFonts.poppins(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                              ),
                            ),
                            if (scanHistory.isNotEmpty) ...[
                              SizedBox(height: 16.h),
                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12.r),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 24.sp,
                                          color: primaryGreen,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Recent Scans',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),
                                    ...scanHistory.take(3).map((scan) {
                                      final parts = scan.split(' - ');
                                      final date = DateTime.parse(parts[0]);
                                      final formattedDate =
                                          DateFormat('MMM d, HH:mm')
                                              .format(date);
                                      return Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 4.h),
                                        child: Text(
                                          '$formattedDate - ${parts[1]}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14.sp,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: 16.h),
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 48.sp,
                                    color: primaryGreen,
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'Scan Customer\'s QR Code',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Position your phone to scan the QR code provided by the customer to confirm waste pickup.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 24.sp,
                                        color: primaryGreen,
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Text(
                                          'How it works',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    '1. Ask customer for their QR code\n2. Scan the code to verify pickup location\n3. Confirm the pickup on next screen\n4. Get customer signature if required',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      color: Colors.grey[600],
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
            },
          ),
        ],
      ),
    );
  }
}
