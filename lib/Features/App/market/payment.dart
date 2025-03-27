import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/home/home.dart';
import 'package:flutternew/Features/App/payment/razer_pay.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddressScreen extends StatefulWidget {
  final Map<String, dynamic> productInfo;

  const AddressScreen({Key? key, required this.productInfo}) : super(key: key);

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _roadController = TextEditingController();
  String? _city;
  String? _state;
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color lightGreen = const Color(0xFF4CAF50);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    _houseController.dispose();
    _roadController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationDetails(String pincode) async {
    final response = await http
        .get(Uri.parse("http://www.postalpincode.in/api/pincode/$pincode"));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['Status'] == 'Success') {
        final postOffice = jsonResponse['PostOffice'][0];
        setState(() {
          _city = postOffice['District'];
          _state = postOffice['State'];
        });
      } else {
        setState(() {
          _city = null;
          _state = null;
        });
        if (mounted) {
          CustomSnackbar.showError(
            context: context,
            message: 'Invalid pincode.',
          );
        }
      }
    } else {
      throw Exception('Failed to load location details');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepperWidget(currentStep: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Delivery Address',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ).animate().fadeIn().slideX(),
                    const SizedBox(height: 24),
                    _buildSavedAddresses(),
                    const SizedBox(height: 24),
                    _buildAddNewAddressButton(),
                    const SizedBox(height: 24),
                    PriceDetailsCard(productInfo: widget.productInfo),
                  ].animate(interval: 100.ms).fadeIn().slideX(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddresses() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUserAddresses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error loading addresses: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'No saved addresses found. Please add a new address.',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ),
          );
        }

        return Column(
          children: snapshot.data!.map((addressData) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(Icons.home, color: primaryGreen),
                title: Text(
                  addressData['name'] ?? 'Name',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addressData['mobile'] ?? 'Mobile',
                      style: GoogleFonts.poppins(),
                    ),
                    Text(
                      addressData['address'] ?? 'Address',
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
                onTap: () {
                  // Parse the full address into components
                  String fullAddress = addressData['address'] ?? '';
                  List<String> addressParts = fullAddress.split(', ');

                  // Extract components from address parts
                  String house = addressParts.isNotEmpty ? addressParts[0] : '';
                  String road = addressParts.length > 1 ? addressParts[1] : '';
                  String city = addressParts.length > 2 ? addressParts[2] : '';
                  String state = addressParts.length > 3 ? addressParts[3] : '';
                  String pincode =
                  addressParts.length > 4 ? addressParts[4] : '';

                  Map<String, String> addressDetails = {
                    'name': addressData['name'] ?? '',
                    'phone': addressData['mobile'] ?? '',
                    'address': fullAddress,
                    'pincode': pincode,
                    'city': city,
                    'state': state,
                    'house': house,
                    'road': road,
                  };

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SummaryScreen(
                        productInfo: widget.productInfo,
                        addressDetails: addressDetails,
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAddNewAddressButton() {
    return ElevatedButton.icon(
      onPressed: () => _showAddAddressForm(),
      icon: const Icon(Icons.add),
      label: Text(
        'Add New Address',
        style: GoogleFonts.poppins(),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserAddresses() async {
    List<Map<String, dynamic>> addresses = [];
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
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

  void _showAddAddressForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                      'Add New Address',
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
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: _buildInputDecoration('Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return 'Please enter phone number';
                        if (value!.length != 10)
                          return 'Please enter a valid 10-digit phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pincodeController,
                      decoration: _buildInputDecoration('Pincode'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return 'Please enter pincode';
                        if (value!.length != 6)
                          return 'Please enter a valid 6-digit pincode';
                        return null;
                      },
                      onChanged: (value) {
                        if (value.length == 6) {
                          _fetchLocationDetails(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: _buildInputDecoration('City'),
                            controller: TextEditingController(text: _city),
                            readOnly: true,
                            validator: (value) =>
                            _city == null || _city!.isEmpty
                                ? 'Please enter city'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: _buildInputDecoration('State'),
                            controller: TextEditingController(text: _state),
                            readOnly: true,
                            validator: (value) =>
                            _state == null || _state!.isEmpty
                                ? 'Please enter state'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _houseController,
                      decoration:
                      _buildInputDecoration('House no / Building Name'),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter building name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roadController,
                      decoration:
                      _buildInputDecoration('Road Name / Area / Colony'),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter road name'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(color: Colors.grey[700]),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => _saveAddress(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Save Address',
                            style: GoogleFonts.poppins(color: Colors.white),
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
      },
    );
  }

  void _saveAddress(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          String fullAddress =
              '${_houseController.text}, ${_roadController.text}, ${_city}, ${_state}, ${_pincodeController.text}';

          await FirebaseFirestore.instance.collection('user_adress_list').add({
            'userId': currentUser.uid,
            'fullname': _nameController.text,
            'mobile': _phoneController.text,
            'address': fullAddress,
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            Navigator.pop(context); // Close the form dialog
            CustomSnackbar.showSuccess(
              context: context,
              message: 'Address saved successfully!',
            );
            setState(() {}); // Refresh the address list
          }
        } catch (e) {
          if (mounted) {
            CustomSnackbar.showError(
              context: context,
              message: 'Failed to save address. Error: ${e.toString()}',
            );
          }
        }
      }
    }
  }
}

class PriceDetailsCard extends StatelessWidget {
  final Map<String, dynamic> productInfo;

  const PriceDetailsCard({Key? key, required this.productInfo})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    double subtotal = 0.0;

    // Calculate subtotal if cart items exist
    if (productInfo['cartItems'] != null) {
      for (var item in (productInfo['cartItems'] as List)) {
        subtotal += (item['price'] * item['quantity']);
      }
    } else {
      subtotal = productInfo['price'].toDouble();
    }

    double cgst = subtotal * 0.09;
    double sgst = subtotal * 0.09;
    double igst = subtotal * 0.18;
    double deliveryCharges = subtotal < 299 ? 99 : 0;
    double totalAmount = subtotal + cgst + sgst + deliveryCharges;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Details',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            if (productInfo['cartItems'] != null)
              ...(productInfo['cartItems'] as List)
                  .map((item) => _buildPriceRow(
                  '${item['title']} (x${item['quantity']})',
                  '₹ ${(item['price'] * item['quantity']).toStringAsFixed(2)}'))
                  .toList(),
            if (productInfo['cartItems'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Colors.grey[300]),
              ),
            _buildPriceRow('Subtotal', '₹ ${subtotal.toStringAsFixed(2)}'),
            _buildPriceRow('CGST (9%)', '₹ ${cgst.toStringAsFixed(2)}'),
            _buildPriceRow('SGST (9%)', '₹ ${sgst.toStringAsFixed(2)}'),
            _buildPriceRow('IGST (18%) - For inter-state only',
                '₹ ${igst.toStringAsFixed(2)}'),
            _buildPriceRow(
                'Delivery Charges', '₹ ${deliveryCharges.toStringAsFixed(2)}'),
            if (subtotal < 299)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'FREE delivery Over ₹299',
                  style: GoogleFonts.poppins(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Free Delivery. (Order value over ₹299)',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Total Amount\n(incl. GST & Delivery)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '₹ ${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class StepperWidget extends StatelessWidget {
  final int currentStep;

  const StepperWidget({Key? key, required this.currentStep}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StepCircle(
            number: 1,
            title: 'Address',
            isActive: currentStep >= 1,
          ),
          _StepperLine(isActive: currentStep >= 2),
          _StepCircle(
            number: 2,
            title: 'Summary',
            isActive: currentStep >= 2,
          ),
          _StepperLine(isActive: currentStep >= 3),
          _StepCircle(
            number: 3,
            title: 'Payment',
            isActive: currentStep >= 3,
          ),
        ],
      ),
    ).animate().fadeIn().slideY();
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final String title;
  final bool isActive;

  const _StepCircle({
    required this.number,
    required this.title,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF2E7D32) : Colors.grey[300],
            ),
            child: Center(
              child: isActive
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                number.toString(),
                style: GoogleFonts.poppins(
                  color: isActive ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: isActive ? const Color(0xFF2E7D32) : Colors.grey[600],
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StepperLine extends StatelessWidget {
  final bool isActive;

  const _StepperLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? const Color(0xFF2E7D32) : Colors.grey[300],
      ),
    );
  }
}

class SummaryScreen extends StatelessWidget {
  final Map<String, dynamic> productInfo;
  final Map<String, String> addressDetails;

  const SummaryScreen(
      {Key? key, required this.productInfo, required this.addressDetails})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate the delivery date (7 days from now)
    DateTime deliveryDate = DateTime.now().add(Duration(days: 7));
    String formattedDate =
        "${deliveryDate.day}/${deliveryDate.month}/${deliveryDate.year}";

    // Calculate total amount
    double price = productInfo['price'].toDouble();
    double cgst = price * 0.09;
    double sgst = price * 0.09;
    double totalPrice = price + cgst + sgst;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepperWidget(currentStep: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Deliver to:',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.edit,
                            color: Color(0xFF2E7D32),
                            size: 18,
                          ),
                          label: Text(
                            'Change',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideX(),
                    const SizedBox(height: 16),
                    AddressCard(addressDetails: addressDetails)
                        .animate()
                        .fadeIn()
                        .slideX(),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Products',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (productInfo['cartItems'] != null)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount:
                              (productInfo['cartItems'] as List).length,
                              itemBuilder: (context, index) {
                                final item =
                                (productInfo['cartItems'] as List)[index];
                                return Container(
                                  margin: EdgeInsets.only(bottom: 16),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border:
                                    Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Image.network(
                                        item['image'],
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['title'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Quantity: ${item['quantity']}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF2E7D32),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            Image.network(
                              productInfo['image'],
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Your order will be delivered on $formattedDate',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideX(),
                    const SizedBox(height: 24),
                    PriceDetailsCard(productInfo: productInfo)
                        .animate()
                        .fadeIn()
                        .slideX(),
                  ],
                ),
              ),
            ),
            _buildBottomButton(context, totalPrice),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                totalPrice: totalPrice,
                addressDetails: addressDetails,
                productInfo: productInfo,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          'Continue to Payment',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AddressCard extends StatelessWidget {
  final Map<String, String> addressDetails;

  const AddressCard({Key? key, required this.addressDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            addressDetails['name'] ?? '',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${addressDetails['house'] ?? ''} , ${addressDetails['road'] ?? ''}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Text(
            '${addressDetails['city'] ?? ''}, ${addressDetails['state'] ?? ''}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phone: ${addressDetails['phone'] ?? ''}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final double totalPrice;
  final Map<String, String> addressDetails;
  final Map<String, dynamic> productInfo;

  const PaymentScreen({
    Key? key,
    required this.totalPrice,
    required this.addressDetails,
    required this.productInfo,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPaymentMethod = 'cod';

  void _createOrder() async {
    // Generate a random order ID (in production, this should come from backend)
    String orderId = DateTime.now().millisecondsSinceEpoch.toString();
    String orderDate = DateTime.now().toString().split(' ')[0];

    // Calculate delivery date (7 days from order date)
    DateTime deliveryDate = DateTime.now().add(Duration(days: 7));
    String formattedDeliveryDate =
        "${deliveryDate.day}/${deliveryDate.month}/${deliveryDate.year}";

    // Calculate delivery charges
    double subtotal = widget.productInfo['cartItems'] != null
        ? (widget.productInfo['cartItems'] as List)
        .fold(0, (sum, item) => sum + (item['price'] * item['quantity']))
        : widget.productInfo['price'].toDouble();
    double deliveryCharges = subtotal < 299 ? 99 : 0;

    // Create order object
    Map<String, dynamic> orderDetails = {
      'orderId': orderId,
      'orderDate': orderDate,
      'deliveryDate': formattedDeliveryDate,
      'status': 'Processing',
      'items': widget.productInfo['cartItems'] ??
          [
            {
              'title': widget.productInfo['title'],
              'price': widget.productInfo['price'],
              'quantity': widget.productInfo['quantity'] ?? 1,
              'image': widget.productInfo['image'],
              'productId': widget.productInfo['productId'],
              'category': widget.productInfo['category'] ?? 'fertilizer',
            }
          ],
      'totalAmount': widget.totalPrice,
      'deliveryCharges': deliveryCharges,
      'shippingAddress': widget.addressDetails,
      'paymentMethod': _selectedPaymentMethod == 'cod'
          ? 'Cash on Delivery'
          : 'Online Payment',
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Save order to Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .set(orderDetails);

      // For COD, create payment history entry
      if (_selectedPaymentMethod == 'cod') {
        final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
        final userId = FirebaseAuth.instance.currentUser?.uid;

        // Store in payment_history
        await FirebaseFirestore.instance
            .collection('payment_history')
            .doc(paymentId)
            .set({
          'userId': userId,
          'amount': widget.totalPrice,
          'status': 'pending', // COD payment is pending until delivery
          'timestamp': FieldValue.serverTimestamp(),
          'details': {
            'paymentMethod': 'Cash on Delivery',
            'orderId': orderId,
          },
        });

        // Store in successful_payments (since order is created)
        await FirebaseFirestore.instance
            .collection('successful_payments')
            .doc(paymentId)
            .set({
          'userId': userId,
          'amount': widget.totalPrice,
          'timestamp': FieldValue.serverTimestamp(),
          'details': {
            'paymentMethod': 'Cash on Delivery',
            'orderId': orderId,
            'status': 'pending',
          },
        });
      }

      // Navigate to home page
      if (mounted) {
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Order placed successfully!',
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const home(),
          ),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context: context,
          message: 'Failed to place order. Please try again.',
        );
      }
    }
  }

  void _handlePaymentProcess() {
    if (_selectedPaymentMethod == 'cod') {
      _createOrder();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RazorpayScreen(
            totalPrice: widget.totalPrice,
            onPaymentSuccess: () {
              _createOrder();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepperWidget(currentStep: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPaymentMethods(),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Payment Method',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentOption(
            icon: Icons.money,
            title: 'Cash on Delivery',
            subtitle: 'Pay when you receive your order',
            value: 'cod',
          ),
          const Divider(height: 24),
          _buildPaymentOption(
            icon: Icons.payment,
            title: 'Online Payment',
            subtitle: 'Pay securely using Razorpay',
            value: 'online',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Row(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Radio(
            value: value,
            groupValue: _selectedPaymentMethod,
            onChanged: (newValue) {
              setState(() {
                _selectedPaymentMethod = newValue.toString();
              });
            },
            activeColor: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _handlePaymentProcess,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          _selectedPaymentMethod == 'cod' ? 'Place Order' : 'Proceed to Pay',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                size: 100,
              ).animate().scale().fadeIn(),
              const SizedBox(height: 24),
              Text(
                'Order Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E7D32),
                ),
              ).animate().fadeIn().slideY(),
              const SizedBox(height: 16),
              Text(
                'Your order has been placed successfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ).animate().fadeIn().slideY(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const home(),
                    ),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn().scale(),
            ],
          ),
        ),
      ),
    );
  }
}
