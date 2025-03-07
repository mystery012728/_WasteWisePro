import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutternew/Features/App/User_auth/presentation/Pages/login_page.dart';
import 'package:flutternew/Features/App/User_auth/presentation/Pages/register.dart';
import 'package:google_fonts/google_fonts.dart';

import 'otp.dart';

class PhoneAuth extends StatelessWidget {
  const PhoneAuth({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PhoneAuthContent();
  }
}

class PhoneAuthContent extends StatefulWidget {
  PhoneAuthContent({Key? key}) : super(key: key);

  @override
  _PhoneAuthContentState createState() => _PhoneAuthContentState();
}

class _PhoneAuthContentState extends State<PhoneAuthContent> with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  late AnimationController _backgroundAnimationController;

  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    phoneController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                      Color(0xFF388E3C),
                    ],
                    transform: GradientRotation(
                      _backgroundAnimationController.value * 2 * 3.14159,
                    ),
                  ),
                ),
              );
            },
          ),

          // Decorative pattern overlay
          Opacity(
            opacity: 0.1,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    'https://www.transparenttextures.com/patterns/recycling-pattern.png',
                  ),
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    _buildBrandingSection(),
                    const SizedBox(height: 40),
                    _buildPhoneAuthForm(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingSection() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            Icons.phone_android,
            size: 60,
            color: Colors.white,
          ),
        ).animate().scale(duration: 600.ms),
        const SizedBox(height: 24),
        Text(
          'Phone Authentication',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ).animate().slideY(begin: -1, duration: 600.ms).fadeIn(),
        const SizedBox(height: 8),
        Text(
          'Enter your phone number to get started',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ).animate().slideY(begin: -1, duration: 600.ms, delay: 200.ms).fadeIn(),
      ],
    );
  }

  Widget _buildPhoneAuthForm() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPhoneField(),
          SizedBox(height: 24),
          if (_errorMessage.isNotEmpty)
            _buildErrorMessage(),
          SizedBox(height: 16),
          _buildGetOTPButton(),
          SizedBox(height: 16),
          _buildDivider(),
          SizedBox(height: 16),
          _buildSignUpLink(),
          SizedBox(height: 16),
          _buildUseEmailLink(),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 800.ms, delay: 200.ms).fadeIn();
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: phoneController,
      style: GoogleFonts.poppins(color: Colors.white),
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        prefixIcon: Icon(Icons.phone, color: Colors.white70),
        prefixText: '+91 ',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        _errorMessage,
        style: GoogleFonts.poppins(color: Colors.red[300], fontSize: 14),
      ),
    ).animate().shake();
  }

  Widget _buildGetOTPButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGetOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.green.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.green.shade800)
            : Text(
          'Get OTP',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ).animate().scale(delay: 600.ms, duration: 400.ms);
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Or', style: GoogleFonts.poppins(color: Colors.white70)),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1)),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Register()));
      },
      child: Text(
        "Don't have an account? Sign Up!",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ).animate().slideY(begin: 0.3, delay: 800.ms, duration: 400.ms);
  }

  Widget _buildUseEmailLink() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
      },
      child: Text(
        'Use Email Instead',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ).animate().slideY(begin: 0.3, delay: 1000.ms, duration: 400.ms);
  }

  Future<void> _handleGetOTP() async {
    if (phoneController.text.length == 10) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          verificationCompleted: (PhoneAuthCredential credential) {},
          verificationFailed: (FirebaseAuthException ex) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Verification failed: ${ex.message}';
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _isLoading = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPScreenApp(verificationid: verificationId),
              ),
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
          phoneNumber: '+91' + phoneController.text,
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number.';
      });
    }
  }
}

