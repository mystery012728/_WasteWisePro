import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/home/home.dart';
import 'package:flutternew/Features/App/payment/razer_pay.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutternew/Features/App/home/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';

class SpecialDaysPage extends StatefulWidget {
  const SpecialDaysPage({super.key});

  @override
  State<SpecialDaysPage> createState() => _SpecialDaysPageState();
}

class _SpecialDaysPageState extends State<SpecialDaysPage> {
  bool isWasteSelected = true;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? pickupAddress;
  bool isCurrentLocation = false;

  Map<String, bool> selectedScrapTypes = {
    'News Paper': false,
    'Office Paper(A3/A4)': false,
    'Books': false,
    'Cardboard': false,
    'Plastic': false,
  };

  final Map<String, double> scrapPrices = {
    'News Paper': 15,
    'Office Paper(A3/A4)': 15,
    'Books': 12,
    'Cardboard': 8,
    'Plastic': 10,
  };

  Map<String, double> scrapWeights = {
    'News Paper': 0,
    'Office Paper(A3/A4)': 0,
    'Books': 0,
    'Cardboard': 0,
    'Plastic': 0,
  };

  List<bool> householdWasteSelection = [false, false, false];
  List<bool> commercialWasteSelection = [false, false, false, false];
  final Color primaryGreen = const Color(0xFF2E7D32);

  // Add weight tracking maps
  Map<String, double> householdWasteWeights = {
    'Mix waste (Wet & Dry)': 0,
    'Wet Waste': 0,
    'Dry Waste': 0,
  };

  Map<String, double> commercialWasteWeights = {
    'Restaurant': 0,
    'Meat & Vegetable Stall': 0,
    'Plastic Waste': 0,
    'Others': 0,
  };

  void _showError(String message) {
    if (mounted) {
      CustomSnackbar.showError(
        context: context,
        message: message,
      );
    }
  }

  bool _validateForm() {
    if (isWasteSelected) {
      bool hasHouseholdSelection = householdWasteSelection.contains(true);
      bool hasCommercialSelection = commercialWasteSelection.contains(true);

      if (!hasHouseholdSelection && !hasCommercialSelection) {
        _showError("Please select at least one waste type");
        return false;
      }

      // Check if selected waste types have weights
      bool hasWeight = false;
      householdWasteWeights.forEach((type, weight) {
        if (householdWasteSelection[[
              'Mix waste (Wet & Dry)',
              'Wet Waste',
              'Dry Waste'
            ].indexOf(type)] &&
            weight > 0) {
          hasWeight = true;
        }
      });
      commercialWasteWeights.forEach((type, weight) {
        if (commercialWasteSelection[[
              'Restaurant',
              'Meat & Vegetable Stall',
              'Plastic Waste',
              'Others'
            ].indexOf(type)] &&
            weight > 0) {
          hasWeight = true;
        }
      });

      if (!hasWeight) {
        _showError("Please enter weight for selected waste types");
        return false;
      }
    } else {
      if (!selectedScrapTypes.containsValue(true)) {
        _showError("Please select at least one scrap type");
        return false;
      }
      bool hasWeight = false;
      selectedScrapTypes.forEach((type, isSelected) {
        if (isSelected && (scrapWeights[type] ?? 0) > 0) {
          hasWeight = true;
        }
      });
      if (!hasWeight) {
        _showError("Please enter weight for selected scrap types");
        return false;
      }
    }

    if (selectedDate == null) {
      _showError("Please select a date");
      return false;
    }

    if (selectedTime == null) {
      _showError("Please select a time");
      return false;
    }

    if (pickupAddress == null) {
      _showError("Please enter a pickup address");
      return false;
    }

    return true;
  }

  void _handlePaymentSuccess() async {
    try {
      // Get current user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("User not authenticated");
      }

      // Parse name and mobile from pickup address
      List<String> addressParts = pickupAddress!.split('\n');
      List<String> contactInfo = addressParts[0].split(' - ');
      String fullname = contactInfo[0];
      String mobile = contactInfo[1];
      String address = addressParts[1];

      // Create notification for successful payment
      await FirebaseFirestore.instance.collection('notifications').add({
        'user_id': currentUser.uid,
        'message': 'Payment successful! Your pickup has been scheduled.',
        'created_at': Timestamp.now(),
        'read': false,
        'type': 'payment_success'
      });

      // Prepare the data to be stored in Firestore
      Map<String, dynamic> specialDayData = {
        'userId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'pickup_date': selectedDate,
        'pickup_time': selectedTime?.format(context),
        'type': isWasteSelected ? 'waste' : 'scrap',
        'customer_fullname': fullname,
        'customer_mobile': mobile,
        'pickup_address': address,
        'is_current_location': isCurrentLocation,
        'total_price': calculateTotalPrice(),
        'payment_status': 'completed',
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'created_by': currentUser.uid,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUser.uid,
      };

      // Use a transaction to ensure both documents are created
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Create a document reference for special day details
        DocumentReference specialDayRef =
            FirebaseFirestore.instance.collection('special_day_details').doc();

        // Create a document reference for upcoming pickup
        DocumentReference pickupRef =
            FirebaseFirestore.instance.collection('upcoming_pickups').doc();

        // Add waste-specific or scrap-specific data
        if (isWasteSelected) {
          // Get selected household waste types
          List<String> selectedHouseholdWaste = [];
          List<String> householdWasteTypes = [
            'Mix waste (Wet & Dry)',
            'Wet Waste',
            'Dry Waste'
          ];

          for (int i = 0; i < householdWasteSelection.length; i++) {
            if (householdWasteSelection[i]) {
              String wasteType = householdWasteTypes[i];
              selectedHouseholdWaste.add(wasteType);
            }
          }

          // Get selected commercial waste types
          List<String> selectedCommercialWaste = [];
          List<String> commercialWasteTypes = [
            'Restaurant',
            'Meat & Vegetable Stall',
            'Plastic Waste',
            'Others'
          ];

          for (int i = 0; i < commercialWasteSelection.length; i++) {
            if (commercialWasteSelection[i]) {
              String wasteType = commercialWasteTypes[i];
              selectedCommercialWaste.add(wasteType);
            }
          }

          // Directly store household and commercial waste types and weights
          specialDayData['household_waste'] = selectedHouseholdWaste;
          specialDayData['commercial_waste'] = selectedCommercialWaste;
          specialDayData['household_waste_weights'] = householdWasteWeights;
          specialDayData['commercial_waste_weights'] = commercialWasteWeights;

          // Set data for special day details
          transaction.set(specialDayRef, specialDayData);

          // Set data for upcoming pickup
          transaction.set(pickupRef, {
            'special_day_id': specialDayRef.id,
            'userId': currentUser.uid,
            'customer_fullname': fullname,
            'customer_mobile': mobile,
            'pickup_date': Timestamp.fromDate(selectedDate!),
            'scheduled_time': selectedTime?.format(context),
            'type': 'special_day',
            'waste_type': 'waste',
            'pickup_address': address,
            'status': 'active',
            'created_at': FieldValue.serverTimestamp(),
            'created_by': currentUser.uid,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': currentUser.uid,
            'household_waste': selectedHouseholdWaste,
            'commercial_waste': selectedCommercialWaste,
            'household_waste_weights': householdWasteWeights,
            'commercial_waste_weights': commercialWasteWeights,
          });
        } else {
          // Handle scrap details
          List<String> scrapTypes = [];

          selectedScrapTypes.forEach((type, isSelected) {
            if (isSelected) {
              scrapTypes.add(type);
            }
          });

          specialDayData['scrap_types'] = scrapTypes;
          specialDayData['scrap_weights'] = scrapWeights;

          // Set data for special day details
          transaction.set(specialDayRef, specialDayData);

          // Set data for upcoming pickup
          transaction.set(pickupRef, {
            'special_day_id': specialDayRef.id,
            'userId': currentUser.uid,
            'customer_fullname': fullname,
            'customer_mobile': mobile,
            'pickup_date': Timestamp.fromDate(selectedDate!),
            'scheduled_time': selectedTime?.format(context),
            'type': 'special_day',
            'waste_type': 'scrap',
            'pickup_address': address,
            'status': 'active',
            'created_at': FieldValue.serverTimestamp(),
            'created_by': currentUser.uid,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': currentUser.uid,
            'scrap_types': scrapTypes,
            'scrap_weights': scrapWeights
          });
        }
      });

      _resetState();
      _showSuccessDialog();
    } catch (e) {
      // Show error message if Firestore operation fails
      if (mounted) {
        CustomSnackbar.showError(
          context: context,
          message: "Error saving pickup details: $e",
        );
      }
    }
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        isWasteSelected = true;
        selectedDate = null;
        selectedTime = null;
        pickupAddress = null;
        isCurrentLocation = false;

        // Reset household waste
        householdWasteSelection = List.filled(3, false);
        householdWasteWeights.updateAll((key, value) => 0);

        // Reset commercial waste
        commercialWasteSelection = List.filled(4, false);
        commercialWasteWeights.updateAll((key, value) => 0);

        // Reset scrap selections and weights
        selectedScrapTypes.updateAll((key, value) => false);
        scrapWeights.updateAll((key, value) => 0);
      });
    }
  }

  List<String> _getSelectedWasteTypes(
      List<bool> selections, List<String> options) {
    List<String> selectedTypes = [];
    for (int i = 0; i < selections.length; i++) {
      if (selections[i]) {
        selectedTypes.add(options[i]);
      }
    }
    return selectedTypes;
  }

  double calculateTotalPrice() {
    if (isWasteSelected) {
      double totalWeight = 0;

      // Add household waste weights
      householdWasteWeights.forEach((type, weight) {
        if (householdWasteSelection[[
          'Mix waste (Wet & Dry)',
          'Wet Waste',
          'Dry Waste'
        ].indexOf(type)]) {
          totalWeight += weight;
        }
      });

      // Add commercial waste weights
      commercialWasteWeights.forEach((type, weight) {
        if (commercialWasteSelection[[
          'Restaurant',
          'Meat & Vegetable Stall',
          'Plastic Waste',
          'Others'
        ].indexOf(type)]) {
          totalWeight += weight;
        }
      });

      return totalWeight * 20; // ₹20 per kg
    } else {
      double total = 0;
      selectedScrapTypes.forEach((type, isSelected) {
        if (isSelected) {
          double weight = scrapWeights[type] ?? 0;
          double pricePerKg = scrapPrices[type] ?? 0;
          total += weight * pricePerKg;
        }
      });
      return total;
    }
  }

  void _showAddressDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Address Option',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchUserAddresses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                  ),
                );
              } else if (snapshot.hasError) {
                return Text(
                  'Error loading addresses: ${snapshot.error}',
                  style: GoogleFonts.poppins(fontSize: 14.sp),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading:
                          Icon(Icons.home, color: primaryGreen, size: 24.sp),
                      title: Text(
                        'No saved addresses found',
                        style: GoogleFonts.poppins(fontSize: 14.sp),
                      ),
                      subtitle: Text(
                        'Please add a new address',
                        style: GoogleFonts.poppins(fontSize: 12.sp),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.add_location_alt,
                          color: primaryGreen, size: 24.sp),
                      title: Text(
                        'Add New Address',
                        style: GoogleFonts.poppins(fontSize: 14.sp),
                      ),
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
                                      leading: Icon(Icons.home,
                                          color: primaryGreen, size: 24.sp),
                                      title: Text(
                                        addressData['name'] ?? 'Name',
                                        style: GoogleFonts.poppins(
                                            fontSize: 14.sp),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            addressData['mobile'] ?? 'Mobile',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12.sp),
                                          ),
                                          Text(
                                            addressData['address'] ?? 'Address',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12.sp),
                                          ),
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
                            Divider(height: 1.h),
                            ListTile(
                              leading: Icon(Icons.add_location_alt,
                                  color: primaryGreen, size: 24.sp),
                              title: Text(
                                'Add New Address',
                                style: GoogleFonts.poppins(fontSize: 14.sp),
                              ),
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

  void _showManualAddressInput() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempAddress = '';
        return AlertDialog(
          title: Text(
            'Enter Address',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: TextField(
            onChanged: (value) {
              tempAddress = value;
            },
            decoration: InputDecoration(
              hintText: "Enter your address",
              hintStyle: GoogleFonts.poppins(),
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text(
                'Save',
                style: GoogleFonts.poppins(color: primaryGreen),
              ),
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Container(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 70.sp,
                ),
                SizedBox(height: 20.h),
                Text(
                  'Pickup Scheduled!',
                  style: GoogleFonts.poppins(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Your pickup request has been scheduled successfully.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const home()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 40.w,
                      vertical: 15.h,
                    ),
                  ),
                  child: Text(
                    'Go to Home',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Special Days',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
              child: Column(
                children: [
                  Text(
                    'Choose Pickup Type',
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          'Waste',
                          true,
                          Icons.delete_outline,
                        ),
                      ),
                      SizedBox(width: 15.w),
                      Expanded(
                        child: _buildTypeButton(
                          'Scrap',
                          false,
                          Icons.recycling,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWasteSelected)
                    _buildWasteSection()
                  else
                    _buildScrapSection(),
                  SizedBox(height: 20.h),
                  _buildDateTimePicker(),
                  SizedBox(height: 30.h),
                  _buildContinueButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String title, bool isWaste, IconData icon) {
    final isSelected = isWasteSelected == isWaste;
    return GestureDetector(
      onTap: () => setState(() {
        isWasteSelected = isWaste;
      }),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.transparent,
            width: 2.w,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryGreen : Colors.white,
              size: 30.sp,
            ),
            SizedBox(height: 10.h),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: isSelected ? primaryGreen : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waste Types',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        SizedBox(height: 10.h),
        _buildWasteTypeContainer(
          'Household Waste',
          ['Mix waste (Wet & Dry)', 'Wet Waste', 'Dry Waste'],
          householdWasteSelection,
          householdWasteWeights,
        ),
        SizedBox(height: 16.h),
        _buildWasteTypeContainer(
          'Commercial Waste',
          ['Restaurant', 'Meat & Vegetable Stall', 'Plastic Waste', 'Others'],
          commercialWasteSelection,
          commercialWasteWeights,
        ),
      ],
    );
  }

  Widget _buildWasteTypeContainer(
    String title,
    List<String> options,
    List<bool> selections,
    Map<String, double> weights,
  ) {
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
            padding: EdgeInsets.all(15.w),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...List.generate(
            options.length,
            (index) => Container(
              margin: EdgeInsets.only(bottom: 10.h),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: Text(
                      options[index],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.sp,
                      ),
                    ),
                    subtitle: Text(
                      '₹20/kg',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 12.sp,
                      ),
                    ),
                    value: selections[index],
                    onChanged: (value) {
                      setState(() {
                        selections[index] = value ?? false;
                        if (!value!) {
                          weights[options[index]] = 0;
                        }
                      });
                    },
                    activeColor: primaryGreen,
                  ),
                  if (selections[index])
                    Padding(
                      padding: EdgeInsets.fromLTRB(15.w, 0, 15.w, 15.h),
                      child: Column(
                        children: [
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter weight in kg',
                              hintStyle: GoogleFonts.poppins(fontSize: 14.sp),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide(color: primaryGreen),
                              ),
                            ),
                            style: GoogleFonts.poppins(fontSize: 14.sp),
                            onChanged: (value) {
                              setState(() {
                                weights[options[index]] =
                                    double.tryParse(value) ?? 0;
                              });
                            },
                          ),
                          if (weights[options[index]]! > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total: ₹${(weights[options[index]]! * 20).toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      color: primaryGreen,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14.sp,
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
          ),
        ],
      ),
    );
  }

  Widget _buildScrapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Normal Recyclables',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        SizedBox(height: 10.h),
        ...scrapPrices.entries
            .map((entry) => Container(
                  margin: EdgeInsets.only(bottom: 10.h),
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
                    children: [
                      CheckboxListTile(
                        title: Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500, fontSize: 14.sp),
                        ),
                        subtitle: Text(
                          '₹${entry.value}/kg',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade600, fontSize: 12.sp),
                        ),
                        value: selectedScrapTypes[entry.key],
                        onChanged: (value) {
                          setState(() {
                            selectedScrapTypes[entry.key] = value ?? false;
                            if (!value!) {
                              scrapWeights[entry.key] = 0;
                            }
                          });
                        },
                        activeColor: primaryGreen,
                      ),
                      if (selectedScrapTypes[entry.key]!)
                        Padding(
                          padding: EdgeInsets.fromLTRB(15.w, 0, 15.w, 15.h),
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter weight in kg',
                              hintStyle: GoogleFonts.poppins(fontSize: 14.sp),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide(color: primaryGreen),
                              ),
                            ),
                            style: GoogleFonts.poppins(fontSize: 14.sp),
                            onChanged: (value) {
                              setState(() {
                                scrapWeights[entry.key] =
                                    double.tryParse(value) ?? 0;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildDateTimePicker() {
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
        children: [
          ListTile(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
              }
            },
            leading: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child:
                  Icon(Icons.calendar_today, color: primaryGreen, size: 24.sp),
            ),
            title: Text(
              'Pickup Date',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16.sp,
              ),
            ),
            subtitle: Text(
              selectedDate != null
                  ? DateFormat('dd MMM yyyy').format(selectedDate!)
                  : 'Select date',
              style: GoogleFonts.poppins(
                color: selectedDate != null
                    ? Colors.black87
                    : Colors.grey.shade600,
                fontSize: 14.sp,
              ),
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1.h),
          ListTile(
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) {
                setState(() => selectedTime = picked);
              }
            },
            leading: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.access_time, color: primaryGreen, size: 24.sp),
            ),
            title: Text(
              'Pickup Time',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16.sp,
              ),
            ),
            subtitle: Text(
              selectedTime != null
                  ? selectedTime!.format(context)
                  : 'Select time',
              style: GoogleFonts.poppins(
                color: selectedTime != null
                    ? Colors.black87
                    : Colors.grey.shade600,
                fontSize: 14.sp,
              ),
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1.h),
          ListTile(
            onTap: _showAddressDialog,
            leading: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.location_on, color: primaryGreen, size: 24.sp),
            ),
            title: Text(
              'Pickup Address',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16.sp,
              ),
            ),
            subtitle: Text(
              pickupAddress ?? 'Enter pickup address',
              style: GoogleFonts.poppins(
                color: pickupAddress != null
                    ? Colors.black87
                    : Colors.grey.shade600,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    double totalPrice = calculateTotalPrice();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20.h),
      child: ElevatedButton(
        onPressed: () {
          if (_validateForm()) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RazorpayScreen(
                  totalPrice: totalPrice,
                  onPaymentSuccess: _handlePaymentSuccess,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          padding: EdgeInsets.symmetric(vertical: 15.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
          elevation: 2,
        ),
        child: Text(
          'Continue - ₹${totalPrice.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
