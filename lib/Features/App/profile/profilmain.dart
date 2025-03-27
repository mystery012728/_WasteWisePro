import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/home/qrcode.dart';
import 'package:flutternew/Features/App/market/ordered_products.dart';
import 'package:flutternew/Features/App/profile/help.dart';
import 'package:flutternew/Features/App/profile/notification_preference.dart';
import 'package:flutternew/Features/App/profile/pickup_history.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutternew/Features/App/User_auth/presentation/Pages/login_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutternew/Features/App/profile/awareness_videos.dart';
import 'package:flutternew/Features/App/profile/rewards.dart';
import 'package:http/http.dart' as http;

class profile extends StatefulWidget {
  const profile({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class AddressScreen extends StatefulWidget {
  final Function(String) onAddressSelected;

  const AddressScreen({Key? key, required this.onAddressSelected})
      : super(key: key);

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
      Navigator.pop(context); // Close the address dialog
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

class _ProfilePageState extends State<profile>
    with SingleTickerProviderStateMixin {
  String _name = "";
  String _email = "";
  String _mobile = "";
  String _address = "";
  String _profilePhotoUrl = "";
  File? _profileImage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;

  // SharedPreferences keys
  static const String KEY_NAME = 'user_name';
  static const String KEY_EMAIL = 'user_email';
  static const String KEY_MOBILE = 'user_mobile';
  static const String KEY_ADDRESS = 'user_address';
  static const String KEY_LAST_UPDATED = 'last_updated';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
    _loadCachedData();
    _fetchUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _name = prefs.getString(KEY_NAME) ?? "";
        _email = prefs.getString(KEY_EMAIL) ?? "";
        _mobile = prefs.getString(KEY_MOBILE) ?? "";
        _address = prefs.getString(KEY_ADDRESS) ?? "";
        _profilePhotoUrl = prefs.getString('profile_photo_url') ?? "";
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(KEY_NAME, _name);
      await prefs.setString(KEY_EMAIL, _email);
      await prefs.setString(KEY_MOBILE, _mobile);
      await prefs.setString(KEY_ADDRESS, _address);
      await prefs.setString('profile_photo_url', _profilePhotoUrl);
      await prefs.setString(KEY_LAST_UPDATED, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving cached data: $e');
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userData = await FirebaseFirestore.instance
            .collection('user_details')
            .doc(currentUser.uid)
            .get();

        if (userData.exists) {
          setState(() {
            _name = userData.data()?['fullName'] ?? "";
            _email = userData.data()?['email'] ?? "";
            _mobile = userData.data()?['mobile'] ?? "";
            _address = userData.data()?['address'] ?? "";
            _profilePhotoUrl = userData.data()?['profilePhotoUrl'] ?? "";
            _isLoading = false;
          });
          // Cache the fetched data
          _saveCachedData();
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData(String newName) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('user_details')
            .doc(currentUser.uid)
            .update({
          'fullName': newName,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        setState(() {
          _name = newName;
        });
        // Update cached data
        _saveCachedData();
      }
    } catch (e) {
      print('Error updating user data: $e');
    }
  }

  Future<void> _updateAllUserData(String newName, String newEmail,
      String newMobile, String newAddress) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade800),
            ),
          ),
        );

        // Identify which fields were changed
        List<String> changedFields = [];
        if (newName != _name) changedFields.add('fullName');
        if (newEmail != _email) changedFields.add('email');
        if (newMobile != _mobile) changedFields.add('mobile');
        if (newAddress != _address) changedFields.add('address');

        // Store edit history only if there are changes
        if (changedFields.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users_edited_details')
              .add({
            'userId': currentUser.uid,
            'previous': {
              'fullName': _name,
              'email': _email,
              'mobile': _mobile,
              'address': _address,
            },
            'updated': {
              'fullName': newName,
              'email': newEmail,
              'mobile': newMobile,
              'address': newAddress,
            },
            'editedAt': FieldValue.serverTimestamp(),
            'fieldsEdited': changedFields,
          });
        }

        // Update user details in the main collection
        await FirebaseFirestore.instance
            .collection('user_details')
            .doc(currentUser.uid)
            .update({
          'fullName': newName,
          'email': newEmail,
          'mobile': newMobile,
          'address': newAddress,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Update local state
        setState(() {
          _name = newName;
          _email = newEmail;
          _mobile = newMobile;
          _address = newAddress;
        });

        // Update cached data
        await _saveCachedData();

        // Close loading indicator
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              changedFields.isEmpty
                  ? 'No changes made'
                  : 'Profile updated successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      // Close loading indicator if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating profile: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      print('Error updating user data: $e');
    }
  }

  Future<void> _pickImageSource(BuildContext context) async {
    final ImagePicker picker = ImagePicker();

    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Profile Photo',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceButton(
                  context,
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _selectImage(picker, ImageSource.gallery);
                  },
                ),
                _buildImageSourceButton(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _selectImage(picker, ImageSource.camera);
                  },
                ),
                _buildImageSourceButton(
                  context,
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePhoto();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, size: 32, color: Colors.green.shade800),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.green.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _selectImage(ImagePicker picker, ImageSource source) async {
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      bool? confirmPhoto = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Confirm Photo',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(image.path), fit: BoxFit.cover),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Use Photo',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirmPhoto == true) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    bool? confirmRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Photo',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        content: Text(
          'Are you sure you want to remove your profile photo?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.green.shade800),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmRemove == true) {
      setState(() {
        _profileImage = null;
      });
    }
  }

  void _showAddressScreen(TextEditingController addressController) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AddressScreen(
            onAddressSelected: (address) async {
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.green.shade800),
                  ),
                ),
              );

              try {
                final User? currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  // Store the previous address for history
                  await FirebaseFirestore.instance
                      .collection('users_edited_details')
                      .add({
                    'userId': currentUser.uid,
                    'previous': {
                      'address': _address,
                      'fullName': _name,
                      'email': _email,
                      'mobile': _mobile,
                    },
                    'updated': {
                      'address': address,
                      'fullName': _name,
                      'email': _email,
                      'mobile': _mobile,
                    },
                    'editedAt': FieldValue.serverTimestamp(),
                    'fieldEdited': 'address',
                  });

                  // Update the main user document
                  await FirebaseFirestore.instance
                      .collection('user_details')
                      .doc(currentUser.uid)
                      .update({
                    'address': address,
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });

                  // Update local state
                  setState(() {
                    _address = address;
                    addressController.text = address;
                  });

                  // Update cached data
                  await _saveCachedData();

                  // Close loading indicator
                  Navigator.pop(context);
                  // Close address screen
                  Navigator.pop(context);

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Address updated successfully!',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green.shade800,
                    ),
                  );

                  // Reopen edit profile dialog
                  Future.delayed(Duration(milliseconds: 100), () {
                    _editProfileName(context);
                  });
                }
              } catch (error) {
                // Close loading indicator
                Navigator.pop(context);
                // Close address screen
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error updating address: $error',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                print('Error updating address: $error');
              }
            },
          ),
        );
      },
    );
  }

  void _editProfileName(BuildContext context) {
    final TextEditingController nameController =
    TextEditingController(text: _name);
    final TextEditingController emailController =
    TextEditingController(text: _email);
    final TextEditingController mobileController =
    TextEditingController(text: _mobile);
    final TextEditingController addressController =
    TextEditingController(text: _address);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: GoogleFonts.poppins(color: Colors.green.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    BorderSide(color: Colors.green.shade600, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.poppins(color: Colors.green.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    BorderSide(color: Colors.green.shade600, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: mobileController,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  labelText: 'Mobile',
                  labelStyle: GoogleFonts.poppins(color: Colors.green.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    BorderSide(color: Colors.green.shade600, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showAddressScreen(addressController);
                },
                child: TextField(
                  controller: addressController,
                  style: GoogleFonts.poppins(),
                  maxLines: 3,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Address (tap to edit)',
                    labelStyle:
                    GoogleFonts.poppins(color: Colors.green.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.green.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                      BorderSide(color: Colors.green.shade600, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.green.shade200),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _updateAllUserData(
                  nameController.text,
                  emailController.text,
                  mobileController.text,
                  addressController.text,
                );
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Name cannot be empty',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.green.shade800),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildProfileHeader(),
                    const SizedBox(height: 40),
                    _buildProfileOptions(),
                  ]
                      .animate(interval: 200.ms)
                      .fadeIn()
                      .slideY(begin: 0.2, end: 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade800),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 75,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 70,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : _profilePhotoUrl.isNotEmpty
                    ? NetworkImage(_profilePhotoUrl) as ImageProvider
                    : const AssetImage('images/profile.jpg'),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => _pickImageSource(context),
                ),
              ),
            ),
          ],
        ).animate().scale(delay: 300.ms),
        const SizedBox(height: 24),
        Text(
          _name,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: 8),
        Text(
          _email,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.green.shade600,
          ),
        ).animate().fadeIn(delay: 600.ms),
        const SizedBox(height: 8),
        Text(
          _mobile,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.green.shade600,
          ),
        ).animate().fadeIn(delay: 700.ms),
        const SizedBox(height: 8),
        Text(
          _address.isNotEmpty ? _address : 'No address added',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.green.shade600,
          ),
        ).animate().fadeIn(delay: 800.ms),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _editProfileName(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Edit Profile',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ).animate().scale(delay: 800.ms),
      ],
    );
  }

  Widget _buildProfileOptions() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildProfileOption(
              icon: Icons.qr_code,
              title: 'Your QR Code',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FixedQRCodePage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildProfileOption(
              icon: Icons.history,
              title: 'Pickup History',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PickupHistoryPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildProfileOption(
              icon: Icons.shopping_cart,
              title: 'Orders',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderedProducts(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildProfileOption(
              icon: Icons.play_circle_outline,
              title: 'Awareness Videos',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AwarenessVideosPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildProfileOption(
              icon: Icons.stars,
              title: 'Your Rewards',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RewardsPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildProfileOption(
              icon: Icons.notifications,
              title: 'Notification Preferences',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationPreferencesPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildProfileOption(
              icon: Icons.help_outline,
              title: 'Help',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildProfileOption(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () => _logout(context),
              isDestructive: true,
            ),
          ],
        ),
      ).animate().slideY(begin: 0.2, end: 0, delay: 900.ms),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.green.shade800,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? Colors.red : Colors.green.shade800,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey.shade200,
      thickness: 1,
      height: 1,
    );
  }
}
