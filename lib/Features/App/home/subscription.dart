import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/home/upcomingpickup.dart';
import 'package:flutternew/Features/App/payment/razer_pay.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutternew/Features/App/home/home.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  final Color lightGreen = const Color(0xFF4CAF50);
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid pincode.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: ${e.toString()}')),
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
      Navigator.of(context).pop();
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
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
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
      final endDate = (activeSubscription['end_date'] as Timestamp).toDate();
      final daysLeft = endDate.difference(DateTime.now()).inDays;

      setState(() {
        isSubscriptionActive = true;
        subscriptionEndDate = endDate;
        activeSubscriptionType =
        activeSubscription['subscription_type'] as String;
      });

      // Check if subscription is about to expire (3 days before)
      if (daysLeft <= 3 && daysLeft > 0) {
        // Create expiry notification
        await FirebaseFirestore.instance.collection('notifications').add({
          'user_id': FirebaseAuth.instance.currentUser?.uid,
          'message':
          'Your $activeSubscriptionType subscription will expire in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}. Please renew to continue our services.',
          'created_at': Timestamp.now(),
          'read': false,
          'type': 'subscription_expiring'
        });
      }
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
      // Get current user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("User not authenticated");
      }

      DateTime endDate;
      double totalPrice =
      isMonthlySelected ? monthlyPrice * monthsCount : weeklyPrice;

      if (isMonthlySelected) {
        endDate = selectedStartDate!.add(Duration(days: monthsCount * 30));
      } else {
        endDate = selectedStartDate!.add(const Duration(days: 7));
      }

      // Parse name and mobile from pickup address
      List<String> addressParts = pickupAddress!.split('\n');
      List<String> contactInfo = addressParts[0].split(' - ');
      String name = contactInfo[0];
      String mobile = contactInfo[1];
      String address = addressParts[1];

      // Create lists of selected waste types
      List<String> selectedHouseholdWaste = [];
      List<String> householdWasteTypes = [
        'Mix waste (Wet & Dry)',
        'Wet Waste',
        'Dry Waste',
        'E-Waste'
      ];
      for (int i = 0; i < householdWasteSelection.length; i++) {
        if (householdWasteSelection[i]) {
          selectedHouseholdWaste.add(householdWasteTypes[i]);
        }
      }

      List<String> selectedCommercialWaste = [];
      List<String> commercialWasteTypes = [
        'Restaurant',
        'Meat & Vegetable Stall',
        'Plastic Waste',
        'Others'
      ];
      for (int i = 0; i < commercialWasteSelection.length; i++) {
        if (commercialWasteSelection[i]) {
          selectedCommercialWaste.add(commercialWasteTypes[i]);
        }
      }

      // Use a transaction to ensure both documents are created
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Create a document reference for subscription details
        DocumentReference subscriptionRef =
        FirebaseFirestore.instance.collection('subscription_details').doc();

        // Create a document reference for upcoming pickup
        DocumentReference pickupRef =
        FirebaseFirestore.instance.collection('upcoming_pickups').doc();

        // Set data for subscription details with userId
        transaction.set(subscriptionRef, {
          'userId': currentUser.uid,
          'subscription_type': isMonthlySelected ? 'Monthly' : 'Weekly',
          'months_count': isMonthlySelected ? monthsCount : null,
          'start_date': selectedStartDate,
          'end_date': endDate,
          'pickup_time': selectedPickUpTime?.format(context),
          'customer_name': name,
          'customer_mobile': mobile,
          'pickup_address': address,
          'is_current_location': isCurrentLocation,
          'household_waste_types': selectedHouseholdWaste,
          'commercial_waste_types': selectedCommercialWaste,
          'total_price': totalPrice,
          'payment_status': 'completed',
          'created_at': FieldValue.serverTimestamp(),
          'status': 'active',
          'pickup_time_changed': false,
          'created_by': currentUser.uid,
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': currentUser.uid,
        });

        // Set data for upcoming pickup with userId
        transaction.set(pickupRef, {
          'subscription_id': subscriptionRef.id,
          'userId': currentUser.uid,
          'customer_name': name,
          'customer_mobile': mobile,
          'pickup_date': Timestamp.fromDate(selectedStartDate!),
          'scheduled_time': selectedPickUpTime?.format(context),
          'subscription_type': isMonthlySelected ? 'Monthly' : 'Weekly',
          'pickup_address': address,
          'household_waste_types': selectedHouseholdWaste,
          'commercial_waste_types': selectedCommercialWaste,
          'status': 'active',
          'type': 'subscription',
          'created_at': FieldValue.serverTimestamp(),
          'created_by': currentUser.uid,
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': currentUser.uid,
        });

        // Create notification for subscription activation
        DocumentReference notificationRef =
        FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(notificationRef, {
          'user_id': currentUser.uid,
          'message':
          'Your ${isMonthlySelected ? "Monthly" : "Weekly"} subscription has been activated successfully! Your first pickup is scheduled for ${DateFormat('MMM d, yyyy').format(selectedStartDate!)} at ${selectedPickUpTime?.format(context)}.',
          'created_at': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'subscription_activated'
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
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchUserAddresses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Text('Error loading addresses: ${snapshot.error}');
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.home, color: primaryGreen),
                      title: Text('No saved addresses found'),
                      subtitle: Text('Please add a new address'),
                    ),
                    ListTile(
                      leading:
                      Icon(Icons.add_location_alt, color: primaryGreen),
                      title: Text('Add New Address'),
                      onTap: () {
                        Navigator.pop(context);
                        _showAddressScreen();
                      },
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...snapshot.data!
                                .map((addressData) => ListTile(
                              leading:
                              Icon(Icons.home, color: primaryGreen),
                              title:
                              Text(addressData['name'] ?? 'Name'),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(addressData['mobile'] ??
                                      'Mobile'),
                                  Text(addressData['address'] ??
                                      'Address'),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  isCurrentLocation = false;
                                  pickupAddress =
                                  '${addressData['name']} - ${addressData['mobile']}\n${addressData['address']}';
                                });
                                Navigator.pop(context);
                              },
                            ))
                                .toList(),
                            const Divider(),
                            ListTile(
                              leading: Icon(Icons.add_location_alt,
                                  color: primaryGreen),
                              title: Text('Add New Address'),
                              onTap: () {
                                Navigator.pop(context);
                                _showAddressScreen();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        );
      },
    );
  }

  void _showAddressScreen() {
    showDialog(
      context: context,
      builder: (context) {
        return AddressScreen(
          onAddressSelected: (addressData) async {
            final User? currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              try {
                await FirebaseFirestore.instance
                    .collection('user_adress_list')
                    .add({
                  'userId': currentUser.uid,
                  'fullname': addressData['name'],
                  'mobile': addressData['mobile'],
                  'address': addressData['address'],
                  'createdAt': FieldValue.serverTimestamp(),
                });

                setState(() {
                  isCurrentLocation = false;
                  pickupAddress =
                  '${addressData['name']} - ${addressData['mobile']}\n${addressData['address']}';
                });

                if (mounted) {
                  CustomSnackbar.showSuccess(
                    context: context,
                    message: 'Address saved successfully!',
                  );
                }
              } catch (e) {
                print('Error saving address: $e');
                if (mounted) {
                  CustomSnackbar.showError(
                    context: context,
                    message: 'Failed to save address. Error: ${e.toString()}',
                  );
                }
              }
            }
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserAddresses() async {
    List<Map<String, dynamic>> addresses = [];
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        // Get addresses from user_adress_list collection only
        final newAddresses = await FirebaseFirestore.instance
            .collection('user_adress_list')
            .where('userId', isEqualTo: currentUser.uid)
            .get();

        if (newAddresses.docs.isNotEmpty) {
          for (var doc in newAddresses.docs) {
            addresses.add({
              'name': doc.data()['fullname'] ?? 'Full Name not provided',
              'mobile': doc.data()['mobile'] ?? 'Mobile not provided',
              'address': doc.data()['address'],
              'source': 'user_adress_list',
              'id': doc.id
            });
          }
        }
      } catch (e) {
        print('Error fetching addresses: $e');
      }
    }

    return addresses;
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
