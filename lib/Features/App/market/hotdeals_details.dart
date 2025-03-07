import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/market/payment.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutternew/Features/App/market/OGprovidere.dart'; // Make sure this is the correct path to your CartProvider

class HotDealsDetails extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color primaryRed = const Color(0xFFB71C1C);
  final Color lightRed = const Color(0xFFEF5350);

  HotDealsDetails({required this.product});

  @override
  Widget build(BuildContext context) {
    final double price = _toDouble(product['price']);
    final double oldPrice = _toDouble(product['oldPrice']);
    final double discountPercentage = oldPrice > price
        ? ((oldPrice - price) / oldPrice) * 100
        : 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryRed,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white)
              .animate()
              .fade()
              .scale(delay: 200.ms),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Hot Deals',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Hero(
                        tag: 'hotdeal-${product['title']}',
                        child: Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: product['image'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryRed),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image, size: 100, color: Colors.red),
                            ),
                          ),
                        ),
                      ).animate().fadeIn().slideX(),
                      if (discountPercentage > 0)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryRed, lightRed],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${discountPercentage.toStringAsFixed(0)}% OFF',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ).animate().fade(delay: 300.ms).scale(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    product['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryRed,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        "₹${NumberFormat('#,##0').format(price)}",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (oldPrice > price)
                        Text(
                          "₹${NumberFormat('#,##0').format(oldPrice)}",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ).animate().fadeIn(delay: 400.ms).slideX(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      product['description'] ?? 'No description available.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildButton(
                    context: context,
                    onPressed: () {
                      Provider.of<CartProvider>(context, listen: false).addToCart({
                        'title': product['title'],
                        'price': price,
                        'image': product['image'],
                        'quantity': 1,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "${product['title']} added to cart",
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: primaryRed,
                        ),
                      );
                    },
                    color: lightRed,
                    text: "Add to Cart",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildButton(
                    context: context,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddressScreen(
                            productInfo: {
                              'title': product['title'],
                              'price': price,
                              'image': product['image'],
                            },
                          ),
                        ),
                      );
                    },
                    color: primaryRed,
                    text: "Buy Now",
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 800.ms).slideY(),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required Color color,
    required String text,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else {
      return 0.0;
    }
  }
}