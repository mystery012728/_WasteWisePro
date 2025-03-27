import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReplaceProductPage extends StatefulWidget {
  final Map<String, dynamic> orderDetails;

  const ReplaceProductPage({
    Key? key,
    required this.orderDetails,
  }) : super(key: key);

  @override
  State<ReplaceProductPage> createState() => _ReplaceProductPageState();
}

class _ReplaceProductPageState extends State<ReplaceProductPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedReason;
  String? additionalNotes;
  bool isLoading = false;

  final List<String> returnReasons = [
    'Product Damaged',
    'Wrong Size',
    'Quality Issues',
    'Not as Described',
    'Changed Mind',
    'Other'
  ];

  Future<void> _submitReturnRequest() async {
    if (selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a reason for return',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Calculate new delivery date (7 days from now)
      final now = DateTime.now();
      final newDeliveryDate = now.add(const Duration(days: 7));
      final formattedDeliveryDate =
      DateFormat('dd/MM/yyyy').format(newDeliveryDate);

      // Create return request
      final returnRequest = {
        'orderId': widget.orderDetails['orderId'],
        'userId': widget.orderDetails['userId'],
        'reason': selectedReason,
        'notes': additionalNotes,
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
        'items': widget.orderDetails['items'],
      };

      // Add return request to collection
      await _firestore.collection('return_requests').add(returnRequest);

      // Create a new order in the orders collection
      final newOrder = {
        ...widget.orderDetails,
        'status': 'Processing',
        'deliveryDate': formattedDeliveryDate,
        'isReplacement': true,
        'originalOrderId': widget.orderDetails['orderId'],
        'replacementReason': selectedReason,
        'replacementNotes': additionalNotes,
        'replacementRequestedAt': DateTime.now().toIso8601String(),
        'orderId':
        '${widget.orderDetails['orderId']}_R', // Add _R suffix for replacement
      };

      // Add to orders collection (for processing orders)
      await _firestore
          .collection('orders')
          .doc(newOrder['orderId'])
          .set(newOrder);

      // Delete from successful_orders since it's now being processed again
      await _firestore
          .collection('successful_orders')
          .doc(widget.orderDetails['orderId'])
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Return request submitted successfully. Your replacement order will be delivered by $formattedDeliveryDate',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit return request: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Return/Replace Product',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${widget.orderDetails['orderId']}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Reason for Return',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...returnReasons.map((reason) => RadioListTile<String>(
              value: reason,
              groupValue: selectedReason,
              title: Text(
                reason,
                style: GoogleFonts.poppins(),
              ),
              onChanged: (value) {
                setState(() {
                  selectedReason = value;
                });
              },
            )),
            const SizedBox(height: 24),
            Text(
              'Additional Notes (Optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter any additional details about your return...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  additionalNotes = value;
                });
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitReturnRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  'Submit Return Request',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
