import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/home/upcomingpickup.dart';
import 'package:flutternew/Features/App/payment/razer_pay.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutternew/Features/App/home/home.dart';

class SubscriptionDetailsPage extends StatefulWidget {
  const SubscriptionDetailsPage({super.key});

  @override
  State<SubscriptionDetailsPage> createState() =>
      _SubscriptionDetailsPageState();
}

class _SubscriptionDetailsPageState extends State<SubscriptionDetailsPage> {
  bool isMonthlySelected = true;
  int monthsCount = 1;
  List<bool> householdWasteSelection = [false, false, false, false];
  List<bool> commercialWasteSelection = [false, false, false, false];
  DateTime? selectedStartDate;
  TimeOfDay? selectedPickUpTime;
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color lightGreen = const Color(0xFF4CAF50);

  final double monthlyPrice = 599.0;
  final double weeklyPrice = 199.0;

  String? pickupAddress;
  bool isCurrentLocation = false;

  bool isSubscriptionActive = false;
  DateTime? subscriptionEndDate;
  String? activeSubscriptionType;

  @override
  void initState() {
    super.initState();
    checkActiveSubscription();
  }

  Future<void> checkActiveSubscription() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('subscription_details')
        .where('status', isEqualTo: 'active')
        .get();

    if (snapshot.docs.isNotEmpty) {
      final activeSubscription =
      snapshot.docs.first.data() as Map<String, dynamic>;
      setState(() {
        isSubscriptionActive = true;
        subscriptionEndDate =
            (activeSubscription['end_date'] as Timestamp).toDate();
        activeSubscriptionType =
        activeSubscription['subscription_type'] as String;
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final DateTime oneMonthLater = tomorrow.add(const Duration(days: 30));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: oneMonthLater,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedStartDate = picked;
      });
    }
  }

  Future<void> _selectPickUpTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: primaryGreen,
              dialHandColor: primaryGreen,
              dialBackgroundColor: Colors.green.shade50,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryGreen,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final int hour = picked.hour;
      if (hour >= 7 && hour <= 23) {
        setState(() {
          selectedPickUpTime = picked;
        });
      } else {
        _showError("Please select a time between 7:00 AM and 11:00 PM");
      }
    }
  }

  bool _validateForm() {
    if (isSubscriptionActive) {
      _showError(
          "You already have an active subscription until ${subscriptionEndDate!.toLocal()}");
      return false;
    }

    // Check if at least one household waste type is selected
    bool isHouseholdWasteSelected = householdWasteSelection.contains(true);

    if (!isHouseholdWasteSelected) {
      _showError("Please select at least one household waste type");
      return false;
    }

    if (selectedStartDate == null) {
      _showError("Please select a starting date");
      return false;
    }

    if (selectedPickUpTime == null) {
      _showError("Please select a pickup time");
      return false;
    }

    if (pickupAddress == null) {
      _showError("Please enter a pickup address");
      return false;
    }

    return true;
  }

  void _showError(String message) {
    if (mounted) {
      CustomSnackbar.showError(
        context: context,
        message: message,
      );
    }
  }

  Future<void> _saveSubscriptionDetails() async {
    try {
      DateTime endDate;
      double totalPrice = isMonthlySelected ? monthlyPrice * monthsCount : weeklyPrice;

      if (isMonthlySelected) {
        endDate = selectedStartDate!.add(Duration(days: monthsCount * 30));
      } else {
        endDate = selectedStartDate!.add(const Duration(days: 7));
      }

      // Create lists of selected waste types
      List<String> selectedHouseholdWaste = [];
      List<String> householdWasteTypes = [
        'Mix waste (Wet & Dry)', 'Wet Waste', 'Dry Waste', 'E-Waste'
      ];
      for (int i = 0; i < householdWasteSelection.length; i++) {
        if (householdWasteSelection[i]) {
          selectedHouseholdWaste.add(householdWasteTypes[i]);
        }
      }

      List<String> selectedCommercialWaste = [];
      List<String> commercialWasteTypes = [
        'Restaurant', 'Meat & Vegetable Stall', 'Plastic Waste', 'Others'
      ];
      for (int i = 0; i < commercialWasteSelection.length; i++) {
        if (commercialWasteSelection[i]) {
          selectedCommercialWaste.add(commercialWasteTypes[i]);
        }
      }

      // Make sure the user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Format pickup time to match the regex pattern in security rules
      String formattedPickupTime = selectedPickUpTime?.format(context) ?? "";

      // Use a transaction to ensure both documents are created
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Create a document reference for subscription details
        DocumentReference subscriptionRef = FirebaseFirestore.instance
            .collection('subscription_details')
            .doc(); // Generate a new document ID

        // Create a document reference for upcoming pickup
        DocumentReference pickupRef = FirebaseFirestore.instance
            .collection('upcoming_pickups')
            .doc(); // Generate a new document ID

        // Set data for subscription details
        transaction.set(subscriptionRef, {
          'userId': user.uid,
          'subscription_type': isMonthlySelected ? 'Monthly' : 'Weekly',
          'months_count': isMonthlySelected ? monthsCount : null,
          'start_date': selectedStartDate,
          'end_date': endDate,
          'pickup_time': formattedPickupTime,
          'pickup_address': pickupAddress,
          'is_current_location': isCurrentLocation,
          'household_waste_types': selectedHouseholdWaste,
          'commercial_waste_types': selectedCommercialWaste,
          'total_price': totalPrice,
          'payment_status': 'completed',
          'created_at': FieldValue.serverTimestamp(),
          'status': 'active',
          'pickup_time_changed': false,
        });

        // Set data for upcoming pickup
        transaction.set(pickupRef, {
          'subscription_id': subscriptionRef.id,
          'userId': user.uid,
          'customer_id': null,
          'pickup_date': Timestamp.fromDate(selectedStartDate!),
          'scheduled_time': formattedPickupTime,
          'subscription_type': isMonthlySelected ? 'Monthly' : 'Weekly',
          'pickup_address': pickupAddress,
          'household_waste_types': selectedHouseholdWaste,
          'commercial_waste_types': selectedCommercialWaste,
          'status': 'active',
          'type': 'subscription',
          'created_at': FieldValue.serverTimestamp()
        });
      });

      _resetState();

      if (mounted) {
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Subscription activated successfully!',
        );
      }
    } catch (e) {
      print('Error saving subscription details: $e');
      if (mounted) {
        CustomSnackbar.showError(
          context: context,
          message: 'Failed to activate subscription. Error: ${e.toString()}',
        );
      }
    }
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        isMonthlySelected = true;
        monthsCount = 1;
        householdWasteSelection = List.filled(4, false);
        commercialWasteSelection = List.filled(4, false);
        selectedStartDate = null;
        selectedPickUpTime = null;
        pickupAddress = null;
        isCurrentLocation = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  void _showAddressDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Address Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.my_location),
                title: Text('Use Current Location'),
                onTap: () {
                  setState(() {
                    isCurrentLocation = true;
                    pickupAddress = "Current Location";
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_location),
                title: Text('Add Address Manually'),
                onTap: () {
                  Navigator.pop(context);
                  _showManualAddressInput();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualAddressInput() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempAddress = '';
        return AlertDialog(
          title: Text('Enter Address'),
          content: TextField(
            onChanged: (value) {
              tempAddress = value;
            },
            decoration: InputDecoration(hintText: "Enter your address"),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                setState(() {
                  isCurrentLocation = false;
                  pickupAddress = tempAddress;
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalPrice =
    isMonthlySelected ? monthlyPrice * monthsCount : weeklyPrice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Subscriptions',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isSubscriptionActive && subscriptionEndDate != null)
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: Colors.green.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: primaryGreen),
                        SizedBox(width: 8),
                        Text(
                          'Active ${activeSubscriptionType ?? ""} Subscription',
                          style: GoogleFonts.poppins(
                            color: primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${subscriptionEndDate!.difference(DateTime.now()).inDays} days left',
                      style: GoogleFonts.poppins(
                        color: primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Choose Your Plan',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select the subscription that works best for you',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPlanButton(
                          'Monthly',
                          true,
                          Icons.calendar_month,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildPlanButton(
                          'Weekly',
                          false,
                          Icons.view_week,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMonthlySelected) _buildMonthsSelector(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Waste Types'),
                  _buildWasteTypeSection(
                    'Household Waste',
                    [
                      'Mix waste (Wet & Dry)',
                      'Wet Waste',
                      'Dry Waste',
                      'E-Waste'
                    ],
                    householdWasteSelection,
                  ),
                  _buildWasteTypeSection(
                    'Commercial Waste',
                    [
                      'Restaurant',
                      'Meat & Vegetable Stall',
                      'Plastic Waste',
                      'Others'
                    ],
                    commercialWasteSelection,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Schedule'),
                  _buildScheduleCard(),
                  const SizedBox(height: 30),
                  _buildContinueButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanButton(String title, bool isMonthly, IconData icon) {
    final isSelected = isMonthlySelected == isMonthly;
    return GestureDetector(
      onTap: () => setState(() => isMonthlySelected = isMonthly),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryGreen : Colors.white,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: isSelected ? primaryGreen : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthsSelector() {
    return Container(
      padding: const EdgeInsets.all(15),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Number of Months',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (monthsCount > 1) {
                    setState(() => monthsCount--);
                  }
                },
                icon: Icon(Icons.remove_circle_outline, color: primaryGreen),
              ),
              Text(
                monthsCount.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => monthsCount++),
                icon: Icon(Icons.add_circle_outline, color: primaryGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryGreen,
        ),
      ),
    );
  }

  Widget _buildWasteTypeSection(
      String title,
      List<String> items,
      List<bool> selectionList,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
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
            padding: const EdgeInsets.all(15),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return CheckboxListTile(
                  title: Text(
                    items[index],
                    style: GoogleFonts.poppins(),
                  ),
                  value: selectionList[index],
                  onChanged: (value) {
                    setState(() {
                      selectionList[index] = value ?? false;
                    });
                  },
                  activeColor: primaryGreen,
                  checkColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
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
        children: [
          ListTile(
            onTap: () => _selectStartDate(context),
            contentPadding: const EdgeInsets.all(15),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today, color: primaryGreen),
            ),
            title: Text(
              'Start Date',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              selectedStartDate != null
                  ? _formatDate(selectedStartDate!)
                  : 'Select date',
              style: GoogleFonts.poppins(
                color: selectedStartDate != null
                    ? Colors.black87
                    : Colors.grey.shade600,
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade600),
          ),
          Divider(color: Colors.grey.shade200, height: 1),
          ListTile(
            onTap: () => _selectPickUpTime(context),
            contentPadding: const EdgeInsets.all(15),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.access_time, color: primaryGreen),
            ),
            title: Text(
              'Pickup Time',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPickUpTime != null
                      ? selectedPickUpTime!.format(context)
                      : 'Select time',
                  style: GoogleFonts.poppins(
                    color: selectedPickUpTime != null
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Available: 7:00 AM - 11:00 PM',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade600),
          ),
          Divider(color: Colors.grey.shade200, height: 1),
          ListTile(
            onTap: _showAddressDialog,
            contentPadding: const EdgeInsets.all(15),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_on, color: primaryGreen),
            ),
            title: Text(
              'Pickup Address',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              pickupAddress ?? 'Enter pickup address',
              style: GoogleFonts.poppins(
                color: pickupAddress != null
                    ? Colors.black87
                    : Colors.grey.shade600,
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    double totalPrice =
    isMonthlySelected ? monthlyPrice * monthsCount : weeklyPrice;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: ElevatedButton(
        onPressed: () {
          if (_validateForm()) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RazorpayScreen(
                  totalPrice: totalPrice,
                  onPaymentSuccess: () {
                    _saveSubscriptionDetails();
                  },
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
        ),
        child: Text(
          'Continue - ₹${totalPrice.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
