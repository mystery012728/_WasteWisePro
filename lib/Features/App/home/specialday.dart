import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/home/home.dart';
import 'package:flutternew/Features/App/payment/razer_pay.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutternew/Features/App/home/subscription.dart';

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
      final user = FirebaseAuth.instance.currentUser;

      // Parse name and mobile from pickup address
      List<String> addressParts = pickupAddress!.split('\n');
      List<String> contactInfo = addressParts[0].split(' - ');
      String fullname = contactInfo[0];
      String mobile = contactInfo[1];
      String address = addressParts[1];

      // Calculate total scrap weight and price if scrap is selected
      double totalScrapWeight = 0.0;
      double totalScrapPrice = 0.0;

      if (!isWasteSelected) {
        // Calculate total scrap weight and price
        selectedScrapTypes.forEach((type, isSelected) {
          if (isSelected) {
            double weight = scrapWeights[type] ?? 0;
            double pricePerKg = scrapPrices[type] ?? 0;
            totalScrapWeight += weight;
            totalScrapPrice += weight * pricePerKg;
          }
        });
      }

      // Prepare the data to be stored in Firestore
      Map<String, dynamic> specialDayData = {
        'userId': user?.uid,
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
      };

      // Use a transaction to ensure both documents are created
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Create a document reference for special day details
        DocumentReference specialDayRef = FirebaseFirestore.instance
            .collection('special_day_details')
            .doc(); // Generate a new document ID

        // Create a document reference for upcoming pickup
        DocumentReference pickupRef = FirebaseFirestore.instance
            .collection('upcoming_pickups')
            .doc(); // Generate a new document ID

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
            'userId': user?.uid,
            'customer_fullname': fullname,
            'customer_mobile': mobile,
            'pickup_date': Timestamp.fromDate(selectedDate!),
            'scheduled_time': selectedTime?.format(context),
            'type': 'special_day',
            'waste_type': 'waste',
            'pickup_address': address,
            'status': 'active',
            'created_at': FieldValue.serverTimestamp(),
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
          // Add total scrap weight and price
          specialDayData['total_scrap_weight'] = totalScrapWeight;
          specialDayData['total_scrap_price'] = totalScrapPrice;

          // Set data for special day details
          transaction.set(specialDayRef, specialDayData);

          // Set data for upcoming pickup
          transaction.set(pickupRef, {
            'special_day_id': specialDayRef.id,
            'userId': user?.uid,
            'customer_fullname': fullname,
            'customer_mobile': mobile,
            'pickup_date': Timestamp.fromDate(selectedDate!),
            'scheduled_time': selectedTime?.format(context),
            'type': 'special_day',
            'waste_type': 'scrap',
            'pickup_address': address,
            'status': 'active',
            'created_at': FieldValue.serverTimestamp(),
            'scrap_types': scrapTypes,
            'scrap_weights': scrapWeights,
            'total_scrap_weight': totalScrapWeight,
            'total_scrap_price': totalScrapPrice
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
      // For scrap, only return service charge
      return 40.0; // Only 40rs service charge for scrap
    }
  }

  // Calculate user earnings from scrap (without service charge)
  double calculateUserEarnings() {
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

  // Calculate total scrap weight
  double calculateTotalScrapWeight() {
    double totalWeight = 0;
    selectedScrapTypes.forEach((type, isSelected) {
      if (isSelected) {
        double weight = scrapWeights[type] ?? 0;
        totalWeight += weight;
      }
    });
    return totalWeight;
  }

  void _showAddressDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Address Option',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
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
                              title: Text(
                                  addressData['name'] ?? 'Full Name'),
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
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 70,
                ),
                const SizedBox(height: 20),
                Text(
                  'Pickup Scheduled!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your pickup request has been scheduled successfully.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: Text(
                    'Go to Home',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Special Days',
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
                    'Choose Pickup Type',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          'Waste',
                          true,
                          Icons.delete_outline,
                        ),
                      ),
                      const SizedBox(width: 15),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWasteSelected)
                    _buildWasteSection()
                  else
                    _buildScrapSection(),
                  const SizedBox(height: 20),
                  _buildDateTimePicker(),
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

  Widget _buildTypeButton(String title, bool isWaste, IconData icon) {
    final isSelected = isWasteSelected == isWaste;
    return GestureDetector(
      onTap: () => setState(() {
        isWasteSelected = isWaste;
      }),
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

  Widget _buildWasteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waste Types',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        _buildWasteTypeContainer(
          'Household Waste',
          ['Mix waste (Wet & Dry)', 'Wet Waste', 'Dry Waste'],
          householdWasteSelection,
        ),
        const SizedBox(height: 16),
        _buildWasteTypeContainer(
          'Commercial Waste',
          ['Restaurant', 'Meat & Vegetable Stall', 'Plastic Waste', 'Others'],
          commercialWasteSelection,
        ),
      ],
    );
  }

  Widget _buildWasteTypeContainer(
      String title, List<String> options, List<bool> selections) {
    Map<String, double> weights = title == 'Household Waste'
        ? householdWasteWeights
        : commercialWasteWeights;

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
            padding: const EdgeInsets.all(15),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...List.generate(
            options.length,
                (index) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: Text(
                      options[index],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '₹20/kg',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
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
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                      child: Column(
                        children: [
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter weight in kg',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: primaryGreen),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                weights[options[index]] =
                                    double.tryParse(value) ?? 0;
                              });
                            },
                          ),
                          if (weights[options[index]]! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total: ₹${(weights[options[index]]! * 20).toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      color: primaryGreen,
                                      fontWeight: FontWeight.w500,
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        ...scrapPrices.entries
            .map((entry) => Container(
          margin: const EdgeInsets.only(bottom: 10),
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
              CheckboxListTile(
                title: Text(
                  entry.key,
                  style:
                  GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '₹${entry.value}/kg',
                  style:
                  GoogleFonts.poppins(color: Colors.grey.shade600),
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
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter weight in kg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryGreen),
                      ),
                    ),
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

        // Add scrap summary section
        if (calculateTotalScrapWeight() > 0)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
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
                Text(
                  'Scrap Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Scrap Weight:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${calculateTotalScrapWeight().toStringAsFixed(2)} kg',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Scrap Price:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${calculateUserEarnings().toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Service Charge:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹40.00',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You will get:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '₹${calculateUserEarnings().toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateTimePicker() {
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today, color: primaryGreen),
            ),
            title: Text(
              'Pickup Date',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              selectedDate != null
                  ? DateFormat('dd MMM yyyy').format(selectedDate!)
                  : 'Select date',
              style: GoogleFonts.poppins(
                color: selectedDate != null
                    ? Colors.black87
                    : Colors.grey.shade600,
              ),
            ),
          ),
          Divider(color: Colors.grey.shade200),
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
            subtitle: Text(
              selectedTime != null
                  ? selectedTime!.format(context)
                  : 'Select time',
              style: GoogleFonts.poppins(
                color: selectedTime != null
                    ? Colors.black87
                    : Colors.grey.shade600,
              ),
            ),
          ),
          Divider(color: Colors.grey.shade200),
          ListTile(
            onTap: _showAddressDialog,
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
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    double totalPrice = calculateTotalPrice();
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
                  onPaymentSuccess: _handlePaymentSuccess,
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
          !isWasteSelected
              ? 'Pay - ₹${totalPrice.toStringAsFixed(2)} (service charges)'
              : 'Pay - ₹${totalPrice.toStringAsFixed(2)}',
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

