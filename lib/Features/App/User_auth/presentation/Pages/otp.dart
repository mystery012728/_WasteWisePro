import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutternew/Features/App/home/home.dart';
import 'package:google_fonts/google_fonts.dart';

class OTPScreenApp extends StatefulWidget {
  final String verificationid;
  OTPScreenApp({Key? key, required this.verificationid}) : super(key: key);

  @override
  State<OTPScreenApp> createState() => _OTPScreenAppState();
}

class _OTPScreenAppState extends State<OTPScreenApp> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  late AnimationController _backgroundAnimationController;
  bool _isLoading = false;
  String _errorMessage = '';

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
    for (var controller in _otpControllers) {
      controller.dispose();
    }
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
                    _buildOTPForm(),
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
        Icon(
          Icons.lock,
          size: 80,
          color: Colors.white,
        ).animate().scale(duration: 600.ms),
        const SizedBox(height: 16),
        Text(
          'Verify OTP',
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
          'Enter the OTP sent to your mobile',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ).animate().slideY(begin: -1, duration: 600.ms, delay: 200.ms).fadeIn(),
      ],
    );
  }

  Widget _buildOTPForm() {
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6,
                  (index) => _buildOTPBox(index),
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage.isNotEmpty)
            _buildErrorMessage(),
          const SizedBox(height: 16),
          _buildVerifyButton(),
          const SizedBox(height: 16),
          _buildResendOTPButton(),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 800.ms, delay: 200.ms).fadeIn();
  }

  Widget _buildOTPBox(int index) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _otpControllers[index],
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 20),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            FocusScope.of(context).nextFocus();
          }
        },
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

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleVerifyOTP,
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
          'Verify OTP',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ).animate().scale(delay: 600.ms, duration: 400.ms);
  }

  Widget _buildResendOTPButton() {
    return TextButton(
      onPressed: () {
        // Handle resend OTP logic
        log('Resend OTP');
      },
      child: Text(
        'Resend OTP',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ).animate().slideY(begin: 0.3, delay: 800.ms, duration: 400.ms);
  }

  Future<void> _handleVerifyOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final otp = _otpControllers.map((controller) => controller.text).join();
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationid,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => home()),
            (route) => false,
      );
    } catch (ex) {
      log(ex.toString());
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid OTP. Please try again.';
      });
    }
  }
}

