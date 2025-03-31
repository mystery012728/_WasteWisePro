import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/home/home.dart';
import 'package:flutternew/Features/App/market/payment.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RazorpayScreen extends StatefulWidget {
  final double totalPrice;
  final VoidCallback onPaymentSuccess;

  const RazorpayScreen({
    Key? key,
    required this.totalPrice,
    required this.onPaymentSuccess,
  }) : super(key: key);

  @override
  _RazorpayScreenState createState() => _RazorpayScreenState();
}

class _RazorpayScreenState extends State<RazorpayScreen> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _openCheckout();
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  void _openCheckout() async {
    var options = {
      'key': 'rzp_test_cFaOVaXjJp8oB2',
      'amount': widget.totalPrice * 100,
      'name': 'Your Company Name',
      'description': 'Subscription Payment',
      'prefill': {
        'email': FirebaseAuth.instance.currentUser?.email ?? 'test@example.com'
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);

      // Store payment attempt in payment_history
      await _storePaymentHistory('initiated', options);
    } catch (e) {
      debugPrint('Error: $e');
      await _storePaymentHistory('failed', {'error': e.toString()});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error initiating payment: $e"),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _storePaymentHistory(
      String status, Map<String, dynamic> details) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final paymentId = DateTime.now().millisecondsSinceEpoch.toString();

      await FirebaseFirestore.instance
          .collection('payment_history')
          .doc(paymentId)
          .set({
        'userId': userId,
        'amount': widget.totalPrice,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });

      // If payment is successful or failed, store in respective collections
      if (status == 'success' || status == 'failed') {
        final collectionName =
        status == 'success' ? 'successful_payments' : 'failed_payments';
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(paymentId)
            .set({
          'userId': userId,
          'amount': widget.totalPrice,
          'timestamp': FieldValue.serverTimestamp(),
          'details': details,
        });
      }

      // Create notification for successful payment
      await FirebaseFirestore.instance.collection('notifications').add({
        'user_id': userId,
        'message': 'Payment successful! Your pickup has been scheduled.',
        'created_at': Timestamp.now(),
        'read': false,
        'type': 'payment_success'
      });
    } catch (e) {
      debugPrint('Error storing payment history: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Store successful payment
    await _storePaymentHistory('success', {
      'paymentId': response.paymentId,
      'orderId': response.orderId,
      'signature': response.signature,
    });

    // Call the onPaymentSuccess callback
    widget.onPaymentSuccess();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Payment successful!"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const home(),
      ),
          (route) => false,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    // Store failed payment
    await _storePaymentHistory('failed', {
      'code': response.code.toString(),
      'message': response.message,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Payment failed: ${response.message}"),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.of(context).pop();
  }

  void _handleExternalWallet(ExternalWalletResponse response) async {
    await _storePaymentHistory('external_wallet', {
      'walletName': response.walletName,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("External wallet selected: ${response.walletName}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 20),
            Text(
              'Processing Payment...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '₹${widget.totalPrice.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
