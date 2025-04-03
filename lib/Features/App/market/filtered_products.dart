import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';

import 'OGprovidere.dart';
import 'fertilizerproduct.dart';
import 'recycle_electronics_details.dart';
import 'recycled_product_details.dart';

class FilteredProducts extends StatefulWidget {
  final String searchQuery;
  final String? selectedCategory;
  final RangeValues? priceRange;
  final double? minRating;

  const FilteredProducts({
    Key? key,
    required this.searchQuery,
    this.selectedCategory,
    this.priceRange,
    this.minRating,
  }) : super(key: key);

  @override
  _FilteredProductsState createState() => _FilteredProductsState();
}

class _FilteredProductsState extends State<FilteredProducts>
    with TickerProviderStateMixin {
  late Stream<List<Map<String, dynamic>>> _productsStream;
  late AnimationController _controller;
  final Color primaryColor = const Color(0xFF2E7D32);

  int _currentPage = 1;
  final int _productsPerPage = 12;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _initializeProductsStream();
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

  void _initializeProductsStream() {
    _productsStream = _getFilteredProducts();
  }

  Stream<List<Map<String, dynamic>>> _getFilteredProducts() {
    // Define collections based on category
    List<String> collections = [];
    if (widget.selectedCategory == null) {
      collections = ['products', 'recycled_electronics', 'recycled_products'];
    } else {
      switch (widget.selectedCategory) {
        case 'Fertilizers':
          collections = ['products'];
          break;
        case 'Recycled Electronics':
          collections = ['recycled_electronics'];
          break;
        case 'Recycled Crafts':
          collections = ['recycled_products'];
          break;
        default:
          collections = [
            'products',
            'recycled_electronics',
            'recycled_products'
          ];
      }
    }

    // Create streams for each collection
    List<Stream<List<Map<String, dynamic>>>> streams =
        collections.map((collection) {
      return FirebaseFirestore.instance
          .collection(collection)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          data['collection'] = collection;
          return data;
        }).toList();
      });
    }).toList();

    // Handle empty streams case
    if (streams.isEmpty) {
      return Stream.value([]);
    }

    // Handle single stream case
    if (streams.length == 1) {
      return streams.first;
    }

    // Combine multiple streams
    return Rx.combineLatestList(streams).map((results) {
      List<Map<String, dynamic>> allProducts = [];
      for (var result in results) {
        allProducts.addAll(result);
      }

      // Apply filters
      final filteredProducts = allProducts.where((product) {
        bool matchesSearch = product['name'].toString().toLowerCase().contains(
              widget.searchQuery.toLowerCase(),
            );

        bool matchesPrice = true;
        if (widget.priceRange != null) {
          double price = product['price'].toDouble();
          matchesPrice = price >= widget.priceRange!.start &&
              price <= widget.priceRange!.end;
        }

        bool matchesRating = true;
        if (widget.minRating != null && product['rating'] != null) {
          matchesRating = product['rating'].toDouble() >= widget.minRating!;
        }

        return matchesSearch && matchesPrice && matchesRating;
      }).toList();

      // Update total pages
      _totalPages = (filteredProducts.length / _productsPerPage).ceil();

      // Apply pagination
      final startIndex = (_currentPage - 1) * _productsPerPage;
      final endIndex = startIndex + _productsPerPage;
      return filteredProducts.sublist(
        startIndex,
        endIndex > filteredProducts.length ? filteredProducts.length : endIndex,
      );
    });
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    double price = product['price'].toDouble();
    double oldPrice = product['oldPrice']?.toDouble() ?? price;
    double discountPercentage =
        oldPrice > price ? ((oldPrice - price) / oldPrice) * 100 : 0;

    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 500),
      openBuilder: (context, _) {
        Widget detailPage;
        switch (product['collection']) {
          case 'products':
            detailPage = FertilizerProduct(productId: product['id']);
            break;
          case 'recycled_electronics':
            detailPage = RecycledElectronicDetail(productId: product['id']);
            break;
          case 'recycled_products':
            detailPage = RecycledProductDetailPage(productId: product['id']);
            break;
          default:
            detailPage = FertilizerProduct(productId: product['id']);
        }
        return detailPage;
      },
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
                    tag: 'product-${product['id']}',
                    child: Container(
                      height: 120.h,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(product['image']),
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
                          product['name'],
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
                              index < (product['rating'] ?? 0).round()
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
                          Provider.of<CartProvider>(context, listen: false)
                              .addToCart({
                            'productId': product['id'],
                            'title': product['name'],
                            'price': price,
                            'image': product['image'],
                            'oldPrice': oldPrice,
                            'quantity': 1,
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("${product['name']} added to cart"),
                              backgroundColor: primaryColor,
                            ),
                          );
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

  @override
  Widget build(BuildContext context) {
    ScreenUtil.instance.init(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search Results',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _productsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading products',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  );
                }

                final products = snapshot.data ?? [];

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64.sp, color: Colors.grey[400]),
                        SizedBox(height: 16.h),
                        Text(
                          'No products found',
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return AnimationLimiter(
                  child: GridView.builder(
                    padding: EdgeInsets.all(16.w),
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
                            child: _buildProductCard(context, products[index]),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _buildPagination(),
        ],
      ),
    );
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
