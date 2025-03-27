import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _message = '';
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _message = '';
      });

      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailController.text.trim(),
        );
        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _message = 'Password reset link has been sent to your email!';
        });
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _message = e.message ?? 'An error occurred while resetting password.';
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _message = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.green.shade600),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Reset Password',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.green.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(color: Colors.green.shade800),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle:
                      GoogleFonts.poppins(color: Colors.green.shade600),
                      prefixIcon:
                      Icon(Icons.email, color: Colors.green.shade600),
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
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  if (_message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isSuccess
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isSuccess
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isSuccess
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: _isSuccess
                                ? Colors.green.shade400
                                : Colors.red.shade400,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message,
                              style: GoogleFonts.poppins(
                                color: _isSuccess
                                    ? Colors.green.shade600
                                    : Colors.red.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
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
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      'Reset Password',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
