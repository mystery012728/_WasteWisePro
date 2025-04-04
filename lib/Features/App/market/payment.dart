import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';
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
      labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14.sp),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: primaryGreen, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepperWidget(currentStep: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Delivery Address',
                      style: GoogleFonts.poppins(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ).animate().fadeIn().slideX(),
                    SizedBox(height: 24.h),
                    _buildSavedAddresses(),
                    SizedBox(height: 24.h),
                    _buildAddNewAddressButton(),
                    SizedBox(height: 24.h),
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
          return Text(
            'Error loading addresses: ${snapshot.error}',
            style: GoogleFonts.poppins(fontSize: 14.sp),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
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
                  fontSize: 14.sp,
                ),
              ),
            ),
          );
        }

        return Column(
          children: snapshot.data!.map((addressData) {
            return Container(
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16.w),
                leading: Icon(Icons.home, color: primaryGreen, size: 24.w),
                title: Text(
                  addressData['name'] ?? 'Name',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addressData['mobile'] ?? 'Mobile',
                      style: GoogleFonts.poppins(fontSize: 14.sp),
                    ),
                    Text(
                      addressData['address'] ?? 'Address',
                      style: GoogleFonts.poppins(fontSize: 14.sp),
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
      icon: Icon(Icons.add, size: 20.w),
      label: Text(
        'Add New Address',
        style: GoogleFonts.poppins(fontSize: 14.sp),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
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
        // Initialize ScreenUtil for the dialog
        ScreenUtil.instance.init(context);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Container(
            padding: EdgeInsets.all(16.w),
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
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('Full Name'),
                      style: GoogleFonts.poppins(fontSize: 14.sp),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter your name'
                          : null,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _phoneController,
                      decoration: _buildInputDecoration('Phone Number'),
                      style: GoogleFonts.poppins(fontSize: 14.sp),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return 'Please enter phone number';
                        if (value!.length != 10)
                          return 'Please enter a valid 10-digit phone number';
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _pincodeController,
                      decoration: _buildInputDecoration('Pincode'),
                      style: GoogleFonts.poppins(fontSize: 14.sp),
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
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: _buildInputDecoration('City'),
                            controller: TextEditingController(text: _city),
                            style: GoogleFonts.poppins(fontSize: 14.sp),
                            readOnly: true,
                            validator: (value) =>
                            _city == null || _city!.isEmpty
                                ? 'Please enter city'
                                : null,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: TextFormField(
                            decoration: _buildInputDecoration('State'),
                            controller: TextEditingController(text: _state),
                            style: GoogleFonts.poppins(fontSize: 14.sp),
                            readOnly: true,
                            validator: (value) =>
                            _state == null || _state!.isEmpty
                                ? 'Please enter state'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _houseController,
                      decoration:
                      _buildInputDecoration('House no / Building Name'),
                      style: GoogleFonts.poppins(fontSize: 14.sp),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter building name'
                          : null,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _roadController,
                      decoration:
                      _buildInputDecoration('Road Name / Area / Colony'),
                      style: GoogleFonts.poppins(fontSize: 14.sp),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter road name'
                          : null,
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        ElevatedButton(
                          onPressed: () => _saveAddress(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                          ),
                          child: Text(
                            'Save Address',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14.sp,
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

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
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Details',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
                color: const Color(0xFF2E7D32),
              ),
            ),
            SizedBox(height: 16.h),
            if (productInfo['cartItems'] != null)
              ...(productInfo['cartItems'] as List)
                  .map((item) => _buildPriceRow(
                  '${item['title']} (x${item['quantity']})',
                  '₹ ${(item['price'] * item['quantity']).toStringAsFixed(2)}'))
                  .toList(),
            if (productInfo['cartItems'] != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
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
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(
                  'FREE delivery Over ₹299',
                  style: GoogleFonts.poppins(
                    color: Colors.green,
                    fontSize: 12.sp,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16.w),
                    SizedBox(width: 4.w),
                    Text(
                      'Free Delivery. (Order value over ₹299)',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
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
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Text(
                  '₹ ${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
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
    // Get ScreenUtil from the context
    final screenUtil = ScreenUtil.instance;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16.sp : 14.sp,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16.sp : 14.sp,
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Container(
      padding: EdgeInsets.all(16.w),
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30.w,
            height: 30.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF2E7D32) : Colors.grey[300],
            ),
            child: Center(
              child: isActive
                  ? Icon(Icons.check, color: Colors.white, size: 18.w)
                  : Text(
                number.toString(),
                style: GoogleFonts.poppins(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: isActive ? const Color(0xFF2E7D32) : Colors.grey[600],
              fontSize: 12.sp,
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
        height: 2.h,
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

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
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Deliver to:',
                          style: GoogleFonts.poppins(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(
                            Icons.edit,
                            color: Color(0xFF2E7D32),
                            size: 18.w,
                          ),
                          label: Text(
                            'Change',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideX(),
                    SizedBox(height: 16.h),
                    AddressCard(addressDetails: addressDetails)
                        .animate()
                        .fadeIn()
                        .slideX(),
                    SizedBox(height: 24.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
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
                              fontSize: 18.sp,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          SizedBox(height: 16.h),
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
                                  margin: EdgeInsets.only(bottom: 16.h),
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    border:
                                    Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Image.network(
                                        item['image'],
                                        height: 60.h,
                                        width: 60.w,
                                        fit: BoxFit.cover,
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['title'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              'Quantity: ${item['quantity']}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey[600],
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                            Text(
                                              '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF2E7D32),
                                                fontSize: 14.sp,
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
                              height: 150.h,
                              fit: BoxFit.cover,
                            ),
                          SizedBox(height: 16.h),
                          Text(
                            'Your order will be delivered on $formattedDate',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideX(),
                    SizedBox(height: 24.h),
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Container(
      padding: EdgeInsets.all(16.w),
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
          minimumSize: Size.fromHeight(50.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.r),
          ),
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        child: Text(
          'Continue to Payment',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${addressDetails['house'] ?? ''} , ${addressDetails['road'] ?? ''}',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.black87,
            ),
          ),
          Text(
            '${addressDetails['city'] ?? ''}, ${addressDetails['state'] ?? ''}',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Phone: ${addressDetails['phone'] ?? ''}',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
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

      // Create order placed notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'message':
        'Your order #$orderId has been placed successfully. Expected delivery by $formattedDeliveryDate.',
        'created_at': Timestamp.now(),
        'read': false,
        'type': 'order_placed'
      });

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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepperWidget(currentStep: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                    SizedBox(height: 24.h),
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
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E7D32),
            ),
          ),
          SizedBox(height: 16.h),
          _buildPaymentOption(
            icon: Icons.money,
            title: 'Cash on Delivery',
            subtitle: 'Pay when you receive your order',
            value: 'cod',
          ),
          Divider(height: 24.h),
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
          Icon(icon, size: 28.w, color: const Color(0xFF2E7D32)),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
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
      padding: EdgeInsets.all(16.w),
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
          minimumSize: Size.fromHeight(50.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.r),
          ),
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        child: Text(
          _selectedPaymentMethod == 'cod' ? 'Place Order' : 'Proceed to Pay',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                size: 100.w,
              ).animate().scale().fadeIn(),
              SizedBox(height: 24.h),
              Text(
                'Order Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E7D32),
                ),
              ).animate().fadeIn().slideY(),
              SizedBox(height: 16.h),
              Text(
                'Your order has been placed successfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
              ).animate().fadeIn().slideY(),
              SizedBox(height: 24.h),
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
                  EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
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