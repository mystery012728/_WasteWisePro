import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/market/OGprovidere.dart';
import 'package:flutternew/Features/App/market/recycle_electronics_details.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';

import 'fertilizerproduct.dart';

class fertilizer extends StatefulWidget {
  @override
  _FertilizerState createState() => _FertilizerState();
}

class _FertilizerState extends State<fertilizer> with TickerProviderStateMixin {
  late AnimationController _controller;
  final Color primaryColor = const Color(0xFF2E7D32);

  int _currentPage = 1;
  final int _productsPerPage = 12;
  int _totalPages = 1;

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
    ScreenUtil.instance.init(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: _buildProductGrid(),
          ),
          _buildPagination(),
        ],
      ),
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
        'Fertilizers',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
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
                    size: 64.sp, color: Colors.grey[400]),
                SizedBox(height: 16.h),
                Text(
                  'No fertilizers available',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16.sp),
                ),
              ],
            ),
          );
        }

        var allProducts = snapshot.data!.docs.toList();
        _totalPages = (allProducts.length / _productsPerPage).ceil();

        var startIndex = (_currentPage - 1) * _productsPerPage;
        var endIndex = startIndex + _productsPerPage;
        if (endIndex > allProducts.length) endIndex = allProducts.length;

        var products = allProducts.sublist(startIndex, endIndex);

        return AnimationLimiter(
          child: GridView.builder(
            padding: EdgeInsets.all(16.w),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 0.65,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 375),
                columnCount: 2,
                child: ScaleAnimation(
                  child: FadeInAnimation(
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
      openBuilder: (context, _) => FertilizerProduct(productId: productId),
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
              color: Colors.green[100]!,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  Hero(
                    tag: 'fertilizer-$productId',
                    child: Container(
                      height: 120.h,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  if (discountPercentage > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '${discountPercentage.toStringAsFixed(0)}% OFF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.sp,
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
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              '₹${NumberFormat('#,##0').format(price)}',
                              style: TextStyle(
                                color: Colors.purple[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            if (oldPrice > price)
                              Text(
                                '₹${NumberFormat('#,##0').format(oldPrice)}',
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 10.sp,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 12.sp,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                        ),
                        child: Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.sp,
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
      'category': 'fertilizer',
    });
    if (mounted) {
      CustomSnackbar.showSuccess(
        context: context,
        message: '${name} added to cart',
      );
    }
  }

  Widget _buildPagination() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: Offset(0, -2.h),
            blurRadius: 10.r,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed:
                _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: Icon(Icons.arrow_back_ios,
                color: _currentPage > 1 ? primaryColor : Colors.grey),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_totalPages, (index) {
              final pageNumber = index + 1;
              final isCurrentPage = pageNumber == _currentPage;

              if (_totalPages <= 5 ||
                  pageNumber == 1 ||
                  pageNumber == _totalPages ||
                  (pageNumber >= _currentPage - 1 &&
                      pageNumber <= _currentPage + 1)) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _currentPage = pageNumber),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCurrentPage ? primaryColor : Colors.white,
                      foregroundColor:
                          isCurrentPage ? Colors.white : primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        side: BorderSide(color: primaryColor),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    ),
                    child: Text(
                      '$pageNumber',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                );
              } else if (pageNumber == _currentPage - 2 ||
                  pageNumber == _currentPage + 2) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text('...',
                      style: TextStyle(color: primaryColor, fontSize: 14.sp)),
                );
              }
              return const SizedBox.shrink();
            }),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: Icon(Icons.arrow_forward_ios,
                color: _currentPage < _totalPages ? primaryColor : Colors.grey),
          ),
        ],
      ),
    );
  }
}
