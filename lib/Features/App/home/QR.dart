import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/notification/background_service.dart';
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
  }

  @override
  void dispose() {
    weightControllers.forEach((_, controller) => controller.dispose());
    _specialDaysPageController.dispose();
    super.dispose();
  }

  Future<void> _disableScanning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SCANNING_ENABLED_KEY, false);
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
      await FirebaseFirestore.instance.collection('missed_pickups').add({
        'subscription_id': subscriptionData!['id'],
        'customer_id': subscriptionData!['customer_id'],
        'scheduled_date': DateTime.now(),
        'scheduled_time': subscriptionData!['pickup_time'],
        'subscription_type': subscriptionData!['subscription_type'],
        'missed_at': DateTime.now(),
        'status': 'missed'
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
              // Trigger background service check
              BackgroundService.initialize();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pickup Confirmation',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryGreen,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subscriptionData != null) _buildSubscriptionCard(),
                  if (specialDaysList.isNotEmpty) ...[
                    SizedBox(height: 20),
                    _buildSpecialDaysSection(),
                  ],
                  SizedBox(height: 20),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_scanner,
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 10),
          Text(
            'QR Code Scanned Successfully',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Verification Code: ${widget.scannedData}',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Subscription Details',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
          Divider(height: 1),
          ListTile(
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
                SizedBox(height: 8),
                Text(
                  'Today\'s Date: ${DateFormat('MMM d, yyyy').format(now)}',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Pickup Time: $pickupTime',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                Text(
                  'Valid: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  subscriptionData!['pickup_address'],
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isSubscriptionCancelled)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Today\'s pickup is cancelled. Service will resume tomorrow.',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isPickupMissed)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Today\'s pickup window has expired. Pickup was scheduled for $pickupTime.',
                            style: GoogleFonts.poppins(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                    if (!isSubscriptionCancelled && !isPickupMissed) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (householdWasteTypes.isNotEmpty) ...[
                              Text(
                                'Household Waste',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryGreen,
                                ),
                              ),
                              SizedBox(height: 8),
                              ...householdWasteTypes.map((type) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextField(
                                  controller: weightControllers[type],
                                  keyboardType:
                                  TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Enter $type weight (kg)',
                                    hintText: 'e.g. 5.5',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    prefixIcon: Icon(Icons.scale,
                                        color: primaryGreen),
                                  ),
                                ),
                              )),
                            ],
                            if (commercialWasteTypes.isNotEmpty) ...[
                              SizedBox(height: 16),
                              Text(
                                'Commercial Waste',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryGreen,
                                ),
                              ),
                              SizedBox(height: 8),
                              ...commercialWasteTypes.map((type) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextField(
                                  controller: weightControllers[type],
                                  keyboardType:
                                  TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Enter $type weight (kg)',
                                    hintText: 'e.g. 5.5',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    prefixIcon: Icon(Icons.scale,
                                        color: primaryGreen),
                                  ),
                                ),
                              )),
                            ],
                            SizedBox(height: 16),
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
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool(SCANNING_ENABLED_KEY, true);
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
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Confirm Subscription Pickup',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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
                fontSize: 18,
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
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios, size: 16),
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
                          icon: Icon(Icons.arrow_forward_ios, size: 16),
                          onPressed: currentSpecialDayIndex < specialDaysList.length - 1
                              ? () {
                            _specialDaysPageController.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                              : null,
                          color: currentSpecialDayIndex < specialDaysList.length - 1
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
        SizedBox(height: 10),
        Container(
          height: 450, // Fixed height for the PageView
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

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Special Day Pickup',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
          Divider(height: 1),
          ListTile(
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
                SizedBox(height: 8),
                Text(
                  'Date: ${DateFormat('MMM d, yyyy').format(pickupDate)}',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                Text(
                  'Time: $pickupTime',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  specialDayData['pickup_address'],
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'waste') ...[
                    // Household waste section
                    if (specialDayData['household_waste'] != null &&
                        (specialDayData['household_waste'] as List).isNotEmpty) ...[
                      Text(
                        'Household Waste',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(specialDayData['household_waste'] as List).map((type) {
                        final controllerKey = 'household_$type';
                        final weight = specialDayData['household_waste_weights']?[type] ?? 0.0;

                        // Initialize controller if it doesn't exist
                        weightControllers.putIfAbsent(controllerKey, () => TextEditingController());

                        // Set text value if weight is greater than 0
                        if (weight > 0) {
                          weightControllers[controllerKey]?.text = weight.toString();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: weightControllers[controllerKey],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Enter $type weight (kg)',
                              hintText: 'e.g. 5.5',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.scale, color: primaryGreen),
                            ),
                          ),
                        );
                      }).toList(),
                    ],

                    // Commercial waste section
                    if (specialDayData['commercial_waste'] != null &&
                        (specialDayData['commercial_waste'] as List).isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Commercial Waste',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(specialDayData['commercial_waste'] as List).map((type) {
                        final controllerKey = 'commercial_$type';
                        final weight = specialDayData['commercial_waste_weights']?[type] ?? 0.0;

                        // Initialize controller if it doesn't exist
                        weightControllers.putIfAbsent(controllerKey, () => TextEditingController());

                        // Set text value if weight is greater than 0
                        if (weight > 0) {
                          weightControllers[controllerKey]?.text = weight.toString();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: weightControllers[controllerKey],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Enter $type weight (kg)',
                              hintText: 'e.g. 5.5',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.scale, color: primaryGreen),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(specialDayData['scrap_types'] as List).map((type) {
                        final controllerKey = 'scrap_$type';
                        final weight = specialDayData['scrap_weights']?[type] ?? 0.0;

                        // Initialize controller if it doesn't exist
                        weightControllers.putIfAbsent(controllerKey, () => TextEditingController());

                        // Set text value if weight is greater than 0
                        if (weight > 0) {
                          weightControllers[controllerKey]?.text = weight.toString();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: weightControllers[controllerKey],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Enter $type weight (kg)',
                              hintText: 'e.g. 5.5',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.scale, color: primaryGreen),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],

                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Collect weights for the current special day
                        Map<String, double> householdWeights = {};
                        Map<String, double> commercialWeights = {};
                        Map<String, double> scrapWeights = {};

                        // Process household waste weights
                        if (specialDayData['household_waste'] != null) {
                          for (var type in specialDayData['household_waste']) {
                            final controllerKey = 'household_$type';
                            if (weightControllers[controllerKey]?.text.isNotEmpty ?? false) {
                              householdWeights[type] = double.parse(weightControllers[controllerKey]!.text);
                            }
                          }
                        }

                        // Process commercial waste weights
                        if (specialDayData['commercial_waste'] != null) {
                          for (var type in specialDayData['commercial_waste']) {
                            final controllerKey = 'commercial_$type';
                            if (weightControllers[controllerKey]?.text.isNotEmpty ?? false) {
                              commercialWeights[type] = double.parse(weightControllers[controllerKey]!.text);
                            }
                          }
                        }

                        // Process scrap weights
                        if (specialDayData['scrap_types'] != null) {
                          for (var type in specialDayData['scrap_types']) {
                            final controllerKey = 'scrap_$type';
                            if (weightControllers[controllerKey]?.text.isNotEmpty ?? false) {
                              scrapWeights[type] = double.parse(weightControllers[controllerKey]!.text);
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
                            'household_waste': specialDayData['household_waste'],
                            'commercial_waste': specialDayData['commercial_waste'],
                            'scrap_types': specialDayData['scrap_types'],
                            'household_waste_weights': householdWeights,
                            'commercial_waste_weights': commercialWeights,
                            'scrap_weights': scrapWeights,
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
                              message: 'Special day pickup confirmed successfully!',
                            );
                          }

                          // Re-enable scanning
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(SCANNING_ENABLED_KEY, true);
                          Navigator.pop(context);
                        } catch (e) {
                          print('Error confirming special day pickup: $e');
                          if (mounted) {
                            CustomSnackbar.showError(
                              context: context,
                              message: 'Failed to confirm pickup. Please try again.',
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Confirm Special Day Pickup',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              // Update special day status to missed
                              await FirebaseFirestore.instance
                                  .collection('special_day_details')
                                  .doc(specialDayData['id'])
                                  .update({
                                'status': 'inactive',
                                'missed_at': Timestamp.now()
                              });

                              // Add to missed pickups
                              await FirebaseFirestore.instance
                                  .collection('missed_pickups')
                                  .add({
                                'special_day_id': specialDayData['id'],
                                'customer_id': specialDayData['userId'],
                                'scheduled_date': specialDayData['pickup_date'],
                                'scheduled_time': specialDayData['pickup_time'],
                                'type': 'special_day',
                                'waste_type': specialDayData['type'],
                                'missed_at': Timestamp.now(),
                                'status': 'missed'
                              });

                              if (mounted) {
                                CustomSnackbar.showSuccess(
                                  context: context,
                                  message: 'Pickup marked as missed!',
                                );
                              }

                              // Re-enable scanning
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(SCANNING_ENABLED_KEY, true);
                              Navigator.pop(context);
                            } catch (e) {
                              print('Error marking pickup as missed: $e');
                              if (mounted) {
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Failed to update pickup status. Please try again.',
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Mark as Missed',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              // Update special day status to cancelled
                              await FirebaseFirestore.instance
                                  .collection('special_day_details')
                                  .doc(specialDayData['id'])
                                  .update({
                                'status': 'inactive',
                                'cancelled_at': Timestamp.now()
                              });

                              // Add to cancelled pickups
                              await FirebaseFirestore.instance
                                  .collection('cancelled_pickups')
                                  .add({
                                'special_day_id': specialDayData['id'],
                                'customer_id': specialDayData['userId'],
                                'date': specialDayData['pickup_date'],
                                'scheduled_time': specialDayData['pickup_time'],
                                'type': 'special_day',
                                'waste_type': specialDayData['type'],
                                'cancelled_at': Timestamp.now(),
                                'status': 'cancelled'
                              });

                              if (mounted) {
                                CustomSnackbar.showSuccess(
                                  context: context,
                                  message: 'Pickup cancelled successfully!',
                                );
                              }

                              // Re-enable scanning
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(SCANNING_ENABLED_KEY, true);
                              Navigator.pop(context);
                            } catch (e) {
                              print('Error cancelling pickup: $e');
                              if (mounted) {
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Failed to cancel pickup. Please try again.',
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel Pickup',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController();
    _initPreferences();
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
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scan Pickup Code',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          setState(() {
                            isFlashOn = !isFlashOn;
                            cameraController.toggleTorch();
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
                        if (!isScanningEnabled) ...[
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Scanning paused',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                isScanningEnabled = true;
                              });
                              await prefs.setBool(SCANNING_ENABLED_KEY, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Resume Scanning',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              'Waste Pickup Verification',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                              ),
                            ),
                            if (scanHistory.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
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
                                          size: 24,
                                          color: primaryGreen,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Recent Scans',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...scanHistory.take(3).map((scan) {
                                      final parts = scan.split(' - ');
                                      final date = DateTime.parse(parts[0]);
                                      final formattedDate =
                                      DateFormat('MMM d, HH:mm')
                                          .format(date);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Text(
                                          '$formattedDate - ${parts[1]}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 48,
                                    color: primaryGreen,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Scan Customer\'s QR Code',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Position your phone to scan the QR code provided by the customer to confirm waste pickup.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 24,
                                        color: primaryGreen,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'How it works',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '1. Ask customer for their QR code\n2. Scan the code to verify pickup location\n3. Confirm the pickup on next screen\n4. Get customer signature if required',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
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

  Future<void> _checkScanningStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final scanningEnabled = prefs.getBool(SCANNING_ENABLED_KEY) ?? true;

    if (mounted && scanningEnabled != isScanningEnabled) {
      setState(() {
        isScanningEnabled = scanningEnabled;
      });
    }
  }
}

