import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutternew/Features/App/market/OGprovidere.dart';
import 'package:flutternew/Features/App/market/payment.dart';
import 'package:flutternew/Features/App/market/product_rating_page.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RecycledElectronicDetail extends StatelessWidget {
  final String productId;
  final Color primaryGrey = const Color(0xFF616161);
  final Color lightGrey = const Color(0xFF9E9E9E);

  const RecycledElectronicDetail({Key? key, required this.productId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryGrey,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white)
              .animate()
              .fade()
              .scale(delay: 200.ms),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Recycled Electronics',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('recycled_electronics')
            .doc(productId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryGrey),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Product not found.',
                style: GoogleFonts.poppins(),
              ),
            );
          }

          var product = snapshot.data!.data() as Map<String, dynamic>;

          // Ensure productId is in the product data
          if (!product.containsKey('productId')) {
            // Add productId to Firestore document if it doesn't exist
            FirebaseFirestore.instance
                .collection('recycled_electronics')
                .doc(productId)
                .update({'productId': productId})
                .then((_) =>
                print('Added productId to recycled electronics document'))
                .catchError(
                    (error) => print('Failed to add productId: $error'));

            // Also add it to our local copy
            product['productId'] = productId;
          }

          String imageUrl = product['image'] ?? '';
          double price = product['price'].toDouble();
          double oldPrice = product['oldPrice']?.toDouble() ?? price;
          double discountPercentage =
          oldPrice > price ? ((oldPrice - price) / oldPrice) * 100 : 0;

          // Get rating data
          double rating = product['rating']?.toDouble() ?? 0.0;
          int reviewCount = product['reviewCount'] as int? ?? 0;
          Map<String, dynamic> ratingStats =
              product['ratingStats'] as Map<String, dynamic>? ??
                  {
                    'average': 0.0,
                    'total': 0,
                    'count': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0}
                  };

          return Column(
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
                            tag: 'electronic-$productId',
                            child: Container(
                              height: 300,
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
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          primaryGrey),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image,
                                      size: 100, color: Colors.red),
                                ),
                              ),
                            ),
                          ).animate().fadeIn().slideX(),
                          if (discountPercentage > 0)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryGrey, lightGrey],
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
                        product['name'] ?? 'No Title',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryGrey,
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
                              color: primaryGrey,
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

                      // Rating section
                      GestureDetector(
                        onTap: () {
                          if (reviewCount > 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductReviewsPage(
                                  productId: productId,
                                  collectionName: 'recycled_electronics',
                                  primaryColor: primaryGrey,
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                    (index) => Icon(
                                  (index < rating.round())
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 24,
                                  color: Colors.amber,
                                )
                                    .animate(delay: (100 * index).ms)
                                    .fadeIn()
                                    .scale(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${rating.toStringAsFixed(1)})',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ],
                        ),
                      ),

                      if (reviewCount > 0) ...[
                        const SizedBox(height: 16),
                        // Rating breakdown
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rating Breakdown',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGrey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Show rating bars
                              ...List.generate(
                                5,
                                    (index) {
                                  // Get count from highest to lowest (5 to 1)
                                  final starNumber = 5 - index;
                                  final count = ratingStats['count']
                                  [starNumber.toString()] as int? ??
                                      0;
                                  final percentage = reviewCount > 0
                                      ? (count / reviewCount * 100)
                                      : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Text(
                                          '$starNumber',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Container(
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                  BorderRadius.circular(4),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: percentage / 100,
                                                child: Container(
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: primaryGrey,
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        4),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 40,
                                          child: Text(
                                            '${percentage.toStringAsFixed(0)}%',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductReviewsPage(
                                        productId: productId,
                                        collectionName: 'recycled_electronics',
                                        primaryColor: primaryGrey,
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.comment, color: primaryGrey),
                                label: Text(
                                  'See All Reviews ($reviewCount)',
                                  style: GoogleFonts.poppins(
                                    color: primaryGrey,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primaryGrey),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

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
                          Provider.of<CartProvider>(context, listen: false)
                              .addToCart({
                            'productId': productId,
                            'title': product['name'],
                            'price': price,
                            'image': product['image'],
                            'oldPrice': oldPrice,
                            'quantity': 1,
                            'category':
                            'recycled_electronics', // Add category for later identification
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${product['name']} added to cart",
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: primaryGrey,
                            ),
                          );
                        },
                        color: lightGrey,
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
                                  'title': product['name'],
                                  'price': price,
                                  'image': product['image'],
                                  'productId': productId,
                                  'category':
                                  'recycled_electronics', // Add category for later identification
                                },
                              ),
                            ),
                          );
                        },
                        color: primaryGrey,
                        text: "Buy Now",
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 800.ms).slideY(),
              ),
            ],
          );
        },
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
}
