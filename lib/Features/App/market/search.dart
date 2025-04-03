import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:provider/provider.dart';
import 'package:flutternew/Features/App/market/fertilizerproduct.dart';
import 'package:flutternew/Features/App/market/recycle_electronics_details.dart';
import 'package:flutternew/Features/App/market/recycled_product_details.dart';
import 'package:flutternew/Features/App/market/OGprovidere.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';

class SearchResultsPage extends StatefulWidget {
  final String searchQuery;
  final String? selectedCategory;
  final RangeValues? priceRange;
  final double? minRating;

  const SearchResultsPage({
    Key? key,
    required this.searchQuery,
    this.selectedCategory,
    this.priceRange,
    this.minRating,
  }) : super(key: key);

  @override
  _SearchResultsPageState createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with TickerProviderStateMixin {
  late Stream<List<Map<String, dynamic>>> _searchResults;
  late AnimationController _controller;
  final Color primaryColor = const Color(0xFF2E7D32);

  int _currentPage = 1;
  final int _productsPerPage = 12;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
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

  void _initializeSearch() {
    _searchResults = _getSearchResults();
  }

  Stream<List<Map<String, dynamic>>> _getSearchResults() {
    // Create a list of collection references to search through
    final collections = [
      'products',
      'recycled_electronics',
      'recycled_products',
    ];

    // Create individual streams for each collection
    final streams = collections.map((collection) {
      return FirebaseFirestore.instance
          .collection(collection)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['collection'] = collection;
          return data;
        }).toList();
      });
    }).toList();

    // Combine streams using Rx.combineLatestList
    return Rx.combineLatestList(streams).map((results) {
      // Flatten the list of lists into a single list
      final allProducts =
          results.expand((products) => products).where((product) {
        // Apply filters
        final matchesSearch = product['name'].toString().toLowerCase().contains(
              widget.searchQuery.toLowerCase(),
            );

        final matchesCategory = widget.selectedCategory == null ||
            product['category'] == widget.selectedCategory;

        final price = (product['price'] as num).toDouble();
        final matchesPrice = widget.priceRange == null ||
            (price >= widget.priceRange!.start &&
                price <= widget.priceRange!.end);

        final rating = (product['rating'] as num?)?.toDouble() ?? 0.0;
        final matchesRating =
            widget.minRating == null || rating >= widget.minRating!;

        return matchesSearch &&
            matchesCategory &&
            matchesPrice &&
            matchesRating;
      }).toList();

      // Sort results by relevance (exact matches first)
      allProducts.sort((a, b) {
        final aName = a['name'].toString().toLowerCase();
        final bName = b['name'].toString().toLowerCase();
        final query = widget.searchQuery.toLowerCase();

        final aExactMatch = aName == query;
        final bExactMatch = bName == query;

        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;

        final aStartsWith = aName.startsWith(query);
        final bStartsWith = bName.startsWith(query);

        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;

        return 0;
      });

      // Update total pages
      _totalPages = (allProducts.length / _productsPerPage).ceil();

      // Apply pagination
      final startIndex = (_currentPage - 1) * _productsPerPage;
      final endIndex = startIndex + _productsPerPage;
      return allProducts.sublist(
        startIndex,
        endIndex > allProducts.length ? allProducts.length : endIndex,
      );
    });
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
              stream: _searchResults,
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
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  );
                }

                final results = snapshot.data ?? [];

                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64.sp, color: Colors.grey[400]),
                        SizedBox(height: 16.h),
                        Text(
                          'No results found',
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Try different keywords or filters',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: Colors.grey[500],
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
                      mainAxisSpacing: 20.h,
                      crossAxisSpacing: 20.w,
                      childAspectRatio: 0.50,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        columnCount: 2,
                        child: ScaleAnimation(
                          child: FadeInAnimation(
                            child: _buildProductCard(context, results[index]),
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

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final price = (product['price'] as num).toDouble();
    final oldPrice = (product['oldPrice'] as num?)?.toDouble() ?? price;
    final discountPercentage =
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
                    tag: 'search-${product['id']}',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(product['image']),
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
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${discountPercentage.toStringAsFixed(0)}% OFF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
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
                    const Spacer(),
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
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                        ),
                        child: Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
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
}
