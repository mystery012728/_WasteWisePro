import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/presentation/Pages/phoneAuth.dart';
import 'package:flutternew/features/app/user_auth/presentation/pages/register.dart';
import 'package:flutternew/features/app/home/home.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutternew/Features/App/User_auth/presentation/Pages/forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/user.phonenumbers.read'
    ],
  );

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
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
                SizedBox(height: 40),
                _buildBrandingSection(),
                SizedBox(height: 40),
                _buildLoginForm(),
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
              'icon/img.png', // Replace with your actual image path
              width: 80,
              height: 80,
            ),
            SizedBox(height: 16),
            Text(
              'WasteWisePro',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Smart waste management solutions',
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

  Widget _buildLoginForm() {
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
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock,
                obscureText: _obscurePassword,
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordPage(),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.poppins(
                      color: Colors.green.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (_errorMessage.isNotEmpty) _buildErrorMessage(),
              SizedBox(height: 16),
              _buildLoginButton(),
              SizedBox(height: 16),
              _buildDivider(),
              SizedBox(height: 16),
              _buildGoogleSignInButton(),
              SizedBox(height: 24),
              _buildSignUpLink(),
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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
        filled: true,
        fillColor: Colors.green.shade50,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      },
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
          SizedBox(width: 12),
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

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.green.shade600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2,
        ),
      )
          : Text(
        'Login',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.green.shade200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(color: Colors.green.shade600),
          ),
        ),
        Expanded(child: Divider(color: Colors.green.shade200)),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return OutlinedButton(
      onPressed: _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Colors.green.shade600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.google, color: Colors.green.shade600),
          SizedBox(width: 8),
          Text(
            'Sign in with Google',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.poppins(color: Colors.green.shade600),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Register()),
            );
          },
          child: Text(
            'Sign Up',
            style: GoogleFonts.poppins(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const home()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Wrong Email or Password.';
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Sign out the user from Google
      await _googleSignIn.signOut();

      // Now initiate the sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // User canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Get the user details from Google account
      final User? user = userCredential.user;
      if (user != null) {
        // Check if user details already exist in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('user_details')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // Get the profile photo URL from Google account
          String? photoURL = user.photoURL;

          // Get phone number from Firebase user if available
          String? phoneNumber = user.phoneNumber;

          // If phone number is not available from Firebase, try to get from Google account
          if (phoneNumber == null || phoneNumber.isEmpty) {
            try {
              // Try to get phone from additional user info if available
              final additionalUserInfo = userCredential.additionalUserInfo;
              if (additionalUserInfo?.profile != null) {
                phoneNumber = additionalUserInfo?.profile?['phone'] as String?;
              }
            } catch (e) {
              print('Error fetching phone number from Google: $e');
            }
          }

          // If user details don't exist, create a new document
          await FirebaseFirestore.instance
              .collection('user_details')
              .doc(user.uid)
              .set({
            'fullName': user.displayName ?? '',
            'email': user.email ?? '',
            'mobile': phoneNumber ?? '',
            'address': '', // Default empty address
            'profilePhotoUrl': photoURL ?? '', // Store the profile photo URL
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'userId': user.uid,
          });
        }
      }

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const home()),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Google Sign-In failed. Please try again.';
      });
      print('Google Sign-In error: $e');
    }
  }
}
