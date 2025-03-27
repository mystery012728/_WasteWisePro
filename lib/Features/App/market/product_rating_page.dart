import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'dart:math' show min, max;

class ProductRatingPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final String collectionName;
  final String orderId;

  const ProductRatingPage({
    Key? key,
    required this.product,
    required this.collectionName,
    required this.orderId,
  }) : super(key: key);

  @override
  State<ProductRatingPage> createState() => _ProductRatingPageState();
}

class _ProductRatingPageState extends State<ProductRatingPage> {
  final TextEditingController _reviewController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  int _rating = 5; // Default rating value
  bool _isSubmitting = false;
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _checkExistingReview();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingReview() async {
    if (_currentUser == null) return;

    try {
      final reviewsSnapshot = await _firestore
          .collection('${widget.collectionName}_reviews')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('productId', isEqualTo: widget.product['productId'])
          .limit(1)
          .get();

      if (reviewsSnapshot.docs.isNotEmpty) {
        final review = reviewsSnapshot.docs.first.data();
        setState(() {
          _hasReviewed = true;
          _rating = review['rating'] as int;
          _reviewController.text = review['review'];
        });
      }
    } catch (e) {
      print('Error checking existing review: $e');
    }
  }

  Future<void> _submitReview() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need to be logged in to submit a review',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      var reviewsCollection =
      _firestore.collection('${widget.collectionName}_reviews');

      // Get the correct productId, ensuring it exists in the product map
      final String productId = widget.product['productId'] ?? '';
      if (productId.isEmpty) {
        throw Exception("Product ID is missing");
      }

      print(
          'Submitting review for productId: $productId in collection: ${widget.collectionName}');

      // Try to find the product first
      final productDoc =
      _firestore.collection(widget.collectionName).doc(productId);
      DocumentSnapshot? productSnapshot;
      try {
        productSnapshot = await productDoc.get();
        if (!productSnapshot.exists) {
          print(
              'Product not found in ${widget.collectionName}. Trying other collections...');

          // Try alternative collections if the product is not found in the expected one
          final List<String> allCollections = [
            'products',
            'recycled_products',
            'recycled_electronics'
          ];
          for (final collection in allCollections) {
            if (collection != widget.collectionName) {
              final altDoc = _firestore.collection(collection).doc(productId);
              final altSnapshot = await altDoc.get();
              if (altSnapshot.exists) {
                print(
                    'Found product in $collection instead of ${widget.collectionName}');
                productSnapshot = altSnapshot;
                // Update the collection
                reviewsCollection =
                    _firestore.collection('${collection}_reviews');
                break;
              }
            }
          }

          if (productSnapshot == null || !productSnapshot.exists) {
            throw Exception(
                "Product not found in any collection. Product ID: $productId");
          }
        }
      } catch (e) {
        print('Error finding product: $e');
        throw Exception("Failed to locate product. Error: $e");
      }

      final timestamp = DateTime.now();
      final reviewData = {
        'productId': productId,
        'userId': _currentUser!.uid,
        'userName': _currentUser!.displayName ?? 'Anonymous',
        'userEmail': _currentUser!.email ?? '',
        'rating': _rating,
        'review': _reviewController.text,
        'timestamp': timestamp,
        'orderId': widget.orderId
      };

      // Add the review to reviews collection
      if (_hasReviewed) {
        // Update existing review
        final reviewQuery = await reviewsCollection
            .where('userId', isEqualTo: _currentUser!.uid)
            .where('productId', isEqualTo: productId)
            .limit(1)
            .get();

        if (reviewQuery.docs.isNotEmpty) {
          await reviewsCollection
              .doc(reviewQuery.docs.first.id)
              .update(reviewData);
        } else {
          // If no existing review found despite _hasReviewed being true
          await reviewsCollection.add(reviewData);
        }
      } else {
        // Add new review
        await reviewsCollection.add(reviewData);
      }

      // Update product rating statistics in the product document
      try {
        await _firestore.runTransaction((transaction) async {
          // Get the latest data in the transaction
          final latestSnapshot = await transaction.get(productDoc);
          if (!latestSnapshot.exists) {
            throw Exception("Product no longer exists");
          }

          final productData = latestSnapshot.data() as Map<String, dynamic>;

          // Get current rating statistics or initialize if not present
          Map<String, dynamic> ratingStats = productData['ratingStats'] ??
              {
                'average': 0.0,
                'total': 0,
                'count': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0}
              };

          // Ensure count map exists
          if (!ratingStats.containsKey('count')) {
            ratingStats['count'] = {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
          }

          // Ensure all rating levels exist in count
          for (int i = 1; i <= 5; i++) {
            final key = i.toString();
            if (!ratingStats['count'].containsKey(key)) {
              ratingStats['count'][key] = 0;
            }
          }

          // If updating an existing review, subtract old rating first
          if (_hasReviewed) {
            int oldRatingCount =
                ratingStats['count'][_rating.toString()] as int? ?? 0;

            // Update count for old rating (ensuring we don't go below 0)
            ratingStats['count'][_rating.toString()] =
                max(0, oldRatingCount - 1);
          } else {
            // Increment total for new review
            ratingStats['total'] = (ratingStats['total'] as int? ?? 0) + 1;
          }

          // Update count for new rating
          int newRatingCount =
              ratingStats['count'][_rating.toString()] as int? ?? 0;
          ratingStats['count'][_rating.toString()] = newRatingCount + 1;

          // Calculate new average
          double totalRating = 0;
          int totalCount = 0;
          for (int i = 1; i <= 5; i++) {
            final count = ratingStats['count'][i.toString()] as int? ?? 0;
            totalRating += i * count;
            totalCount += count;
          }
          ratingStats['average'] =
          totalCount > 0 ? totalRating / totalCount : 0.0;

          // Update product document
          transaction.update(productDoc, {
            'ratingStats': ratingStats,
            'rating': ratingStats['average'],
            'reviewCount': ratingStats['total']
          });
        });
      } catch (e) {
        print('Error updating product statistics: $e');
        // Continue execution since the review was still submitted
      }

      // Update orders document to mark the product as reviewed
      if (!_hasReviewed) {
        try {
          final orderDoc =
          _firestore.collection('successful_orders').doc(widget.orderId);
          final orderSnapshot = await orderDoc.get();

          if (orderSnapshot.exists) {
            final orderData = orderSnapshot.data() as Map<String, dynamic>;
            final items = List<dynamic>.from(orderData['items']);

            // Find and update the reviewed item
            bool itemFound = false;
            for (int i = 0; i < items.length; i++) {
              if (items[i]['productId'] == productId) {
                items[i]['reviewed'] = true;
                itemFound = true;
                break;
              }
            }

            if (itemFound) {
              await orderDoc.update({'items': items});
            } else {
              print('Product ID not found in order items');
            }
          } else {
            print('Order document not found');
          }
        } catch (e) {
          print('Error updating order document: $e');
          // Continue execution since the review was still submitted
        }
      }

      setState(() {
        _isSubmitting = false;
        _hasReviewed = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your review has been submitted successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error in _submitReview: $e');
      setState(() {
        _isSubmitting = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error submitting review: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine theme color based on collection name
    Color primaryColor;
    switch (widget.collectionName) {
      case 'recycled_products':
        primaryColor = const Color(0xFF1976D2); // Blue
        break;
      case 'recycled_electronics':
        primaryColor = const Color(0xFF616161); // Grey
        break;
      case 'products': // Fertilizer
        primaryColor = const Color(0xFF2E7D32); // Green
        break;
      default:
        primaryColor = const Color(0xFF2E7D32); // Default to green
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Rate & Review',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.product['image'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product['title'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${widget.orderId.substring(0, min(8, widget.orderId.length))}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Rating section
            Center(
              child: Column(
                children: [
                  Text(
                    'Rate this product',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RatingBar.builder(
                    initialRating: _rating.toDouble(),
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: false,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) {
                      setState(() {
                        _rating = rating.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRatingDescription(_rating),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Review section
            Text(
              'Write your review',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share your experience with this product...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Debug info
            if (widget.product['productId'] != null) ...[
              Text(
                'Product ID: ${widget.product['productId']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  _hasReviewed ? 'Update Review' : 'Submit Review',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Below Average';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

class ProductReviewsPage extends StatelessWidget {
  final String productId;
  final String collectionName;
  final Color primaryColor;

  const ProductReviewsPage({
    Key? key,
    required this.productId,
    required this.collectionName,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Customer Reviews',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('${collectionName}_reviews')
            .where('productId', isEqualTo: productId)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No reviews yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to review this product',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final reviews = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (context, index) => Divider(height: 32),
            itemBuilder: (context, index) {
              final review = reviews[index].data() as Map<String, dynamic>;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.2),
                        child: Text(
                          (review['userName'] as String).isNotEmpty
                              ? (review['userName'] as String)[0].toUpperCase()
                              : 'A',
                          style: GoogleFonts.poppins(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review['userName'] ?? 'Anonymous',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(
                              (review['timestamp'] as Timestamp).toDate(),
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(
                      5,
                          (i) => Icon(
                        i < (review['rating'] as int)
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review['review'] ?? '',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
