import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/features/app/user_auth/presentation/pages/login_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    addressController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Fixed: removed space in method name
  Future<void> _storeUserDetails(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('user_details').doc(uid).set({
        'fullName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'mobile': mobileController.text.trim(),
        'address': addressController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': uid,
      });
    } catch (e) {
      throw Exception('Failed to store user details: $e');
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mobile number is required';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  Future<void> _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Create user in Firebase Auth
        // Fixed: corrected method name
        final UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Store additional user details in Firestore
        // Fixed: corrected method name
        await _storeUserDetails(userCredential.user!.uid);

        if (mounted) {
          CustomSnackbar.showSuccess(
            context: context,
            message: 'Registration Successful!',
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
          if (e.code == 'weak-password') {
            _errorMessage = 'The password provided is too weak.';
          } else if (e.code == 'email-already-in-use') {
            _errorMessage = 'An account already exists for this email.';
          } else {
            _errorMessage =
                e.message ?? 'An error occurred during registration.';
          }
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  void _showAddressScreen() {
    showDialog(
      context: context,
      builder: (context) {
        return AddressScreen(
          onAddressSelected: (address) {
            addressController.text = address;
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildBrandingSection(),
                const SizedBox(height: 40),
                _buildRegistrationForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Image.asset(
              'icon/img.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Create Account',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join our community today',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.green.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: mobileController,
                label: 'Mobile Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: _validateMobile,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _showAddressScreen,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: addressController,
                    label: 'Address',
                    icon: Icons.location_on,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your address';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: passwordController,
                label: 'Password',
                icon: Icons.lock,
                obscureText: _obscurePassword,
                validator: _validatePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.green.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty) _buildErrorMessage(),
              const SizedBox(height: 24),
              _buildRegisterButton(),
              const SizedBox(height: 16),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.green.shade800),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.green.shade600),
        prefixIcon: Icon(icon, color: Colors.green.shade600),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade400),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.green.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleRegistration,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2,
        ),
      )
          : Text(
        'Create Account',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: GoogleFonts.poppins(color: Colors.green.shade600),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
          child: Text(
            'Login',
            style: GoogleFonts.poppins(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class AddressScreen extends StatefulWidget {
  final Function(String) onAddressSelected;

  const AddressScreen({Key? key, required this.onAddressSelected}) : super(key: key);

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
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
      final response = await http.get(
          Uri.parse("http://www.postalpincode.in/api/pincode/$pincode")
      );

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
      String address = '${_houseController.text}, ${_roadController.text}, ${_city ?? ''}, ${_state ?? ''}, ${_pincodeController.text}';
      widget.onAddressSelected(address);
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
                  controller: _houseController,
                  decoration: _buildInputDecoration('House no / Building Name'),
                  style: GoogleFonts.poppins(),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter building name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roadController,
                  decoration: _buildInputDecoration('Road Name / Area / Colony'),
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
                            validator: (value) => _city == null || _city!.isEmpty
                                ? 'Please enter valid pincode to get city' : null,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
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
                            ? 'Please enter valid pincode to get state' : null,
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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