import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/market/OGprovidere.dart';
import 'package:flutternew/Features/App/market/recycled_product_details.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class RecycledProductsPage extends StatefulWidget {
  @override
  _RecycledProductsPageState createState() => _RecycledProductsPageState();
}

class _RecycledProductsPageState extends State<RecycledProductsPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  final Color primaryColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: primaryColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Recycled Crafts',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('recycled_products')
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.devices_other_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Recycled Products Available',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        var products = snapshot.data!.docs.toList();

        return AnimationLimiter(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.50,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 375),
                columnCount: 2,
                child: FadeInAnimation(
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: _buildProductCard(
                      context: context,
                      productId: products[index].id,
                      name: products[index]['name'],
                      price: products[index]['price'].toDouble(),
                      oldPrice: products[index]['oldPrice']?.toDouble() ??
                          products[index]['price'].toDouble(),
                      rating: products[index]['rating']?.toDouble() ?? 0.0,
                      image: products[index]['image'],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard({
    required BuildContext context,
    required String productId,
    required String name,
    required double price,
    required double oldPrice,
    required double rating,
    required String image,
  }) {
    double discountPercentage =
    oldPrice > price ? ((oldPrice - price) / oldPrice) * 100 : 0;

    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 500),
      openBuilder: (context, _) =>
          RecycledProductDetailPage(productId: productId),
      closedShape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      closedElevation: 0,
      closedColor: Colors.transparent,
      closedBuilder: (context, openContainer) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue[100]!,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Hero(
                    tag: 'recycled-$productId',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  if (discountPercentage > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${discountPercentage.toStringAsFixed(0)}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${NumberFormat('#,##0').format(price)}',
                          style: TextStyle(
                            color: Colors.purple[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (oldPrice > price)
                          Text(
                            '₹${NumberFormat('#,##0').format(oldPrice)}',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                            (index) => Icon(
                          index < rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _addToCart(
                              context, productId, name, price, image, oldPrice);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, String productId, String name,
      double price, String image, double oldPrice) {
    Provider.of<CartProvider>(context, listen: false).addToCart({
      'productId': productId,
      'title': name,
      'price': price,
      'image': image,
      'oldPrice': oldPrice,
      'quantity': 1,
      'category': 'recycled_craft',
    });
    if (mounted) {
      CustomSnackbar.showSuccess(
        context: context,
        message: '${name} added to cart',
      );
    }
  }
}
