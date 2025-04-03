import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/market/OGprovidere.dart';
import 'package:flutternew/Features/App/market/filter.dart';
import 'package:flutternew/Features/App/market/filtered_products.dart';
import 'package:flutternew/Features/App/market/recycled_electronics.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutternew/features/app/market/fertilizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';
import 'cart.dart';
import 'firestore_service.dart';
import 'hotdeals_details.dart';
import 'recycled_product.dart';

class StorePage extends StatefulWidget {
  const StorePage({Key? key}) : super(key: key);

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  RangeValues? _priceRange;
  double? _minRating;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FilterDialog(
        selectedCategory: _selectedCategory,
        priceRange: _priceRange,
        minRating: _minRating,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCategory = result['category'];
        _priceRange = result['priceRange'];
        _minRating = result['minRating'];
      });

      // Navigate to FilteredProducts with empty search query and applied filters
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FilteredProducts(
            searchQuery: '',
            selectedCategory: _selectedCategory,
            priceRange: _priceRange,
            minRating: _minRating,
          ),
        ),
      );
    }
  }

  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredProducts(
          searchQuery: query,
          selectedCategory: _selectedCategory,
          priceRange: _priceRange,
          minRating: _minRating,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon:
              Icon(Icons.filter_list, color: Colors.teal.shade700, size: 24.sp),
          onPressed: _showFilterDialog,
        ),
        title: Container(
          height: 40.h,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon:
                  Icon(Icons.search, color: Colors.teal.shade700, size: 20.sp),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              suffixIcon: IconButton(
                icon:
                    Icon(Icons.clear, color: Colors.grey.shade600, size: 20.sp),
                onPressed: () {
                  _searchController.clear();
                },
              ),
            ),
            style: GoogleFonts.poppins(fontSize: 14.sp),
            onSubmitted: _handleSearch,
            textInputAction: TextInputAction.search,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart,
                color: Colors.teal.shade700, size: 24.sp),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildStoreBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeCard(),
        SizedBox(height: 24.h),
        _buildCategoriesSection(context),
        SizedBox(height: 24.h),
        _buildHotDealsSection(context),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: EdgeInsets.all(16.w),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade400,
                  Colors.teal.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade200.withOpacity(0.5),
                  blurRadius: 20.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eco-Friendly Shopping',
                  style: GoogleFonts.poppins(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Discover sustainable products that make a difference',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideX(begin: -0.2, end: 0, duration: 600.ms)
              .then()
              .shimmer(duration: 1200.ms, delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Categories',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 140.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            children: [
              _buildCategoryCard(
                context,
                title: 'Fertilizers',
                icon: Icons.eco,
                page: fertilizer(),
                color: Colors.green.shade400,
              ),
              _buildCategoryCard(
                context,
                title: 'Recycled\nCrafts',
                icon: Icons.recycling,
                page: RecycledProductsPage(),
                color: Colors.blue.shade400,
              ),
              _buildCategoryCard(
                context,
                title: 'Recycled\nElectronics',
                icon: Icons.electric_bolt,
                page: RecycledElectronics(),
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget page,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      ),
      child: Container(
        width: 160.w,
        margin: EdgeInsets.symmetric(horizontal: 6.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15.w,
              bottom: -15.h,
              child: Icon(
                icon,
                size: 80.sp,
                color: color.withOpacity(0.2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 32.sp, color: color),
                  SizedBox(height: 12.h),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.2, end: 0, duration: 600.ms)
          .then()
          .shimmer(duration: 1200.ms),
    );
  }

  Widget _buildHotDealsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Hot Deals',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.getHotDealsProducts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.teal.shade700),
                ),
              );
            }

            final products = snapshot.data!;
            return SizedBox(
              height: 300.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final double price = (product['price'] != null)
                      ? (product['price'] is int
                          ? (product['price'] as int).toDouble()
                          : (product['price'] as double))
                      : 0.0;

                  final double oldPrice = (product['oldPrice'] != null)
                      ? (product['oldPrice'] is int
                          ? (product['oldPrice'] as int).toDouble()
                          : (product['oldPrice'] as double))
                      : 0.0;

                  final double discountPercentage =
                      oldPrice > 0 ? ((oldPrice - price) / oldPrice) * 100 : 0;

                  final double rating = (product['rating'] != null)
                      ? (product['rating'] is int
                          ? (product['rating'] as int).toDouble()
                          : (product['rating'] as double))
                      : 0.0;

                  final int reviewCount = product['reviewCount'] as int? ?? 0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              HotDealsDetails(product: product),
                        ),
                      );
                    },
                    child: _buildProductCard(
                      context: context,
                      title: product['title'],
                      price: price,
                      oldPrice: oldPrice,
                      tag: product['tag'],
                      asset: product['image'],
                      discountPercentage: discountPercentage,
                      product: product,
                      rating: rating,
                      reviewCount: reviewCount,
                    ).animate(delay: (index * 100).ms).fadeIn().slideX(),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductCard({
    required BuildContext context,
    required String title,
    required double price,
    required double oldPrice,
    required String tag,
    required String asset,
    required double discountPercentage,
    required Map<String, dynamic> product,
    required double rating,
    required int reviewCount,
  }) {
    return Container(
      width: 180.w,
      margin: EdgeInsets.only(right: 12.w, bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                child: CachedNetworkImage(
                  imageUrl: asset,
                  height: 120.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade100,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.teal.shade700),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.error,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
              if (tag.isNotEmpty)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade100,
                          blurRadius: 4.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.sp,
                      ),
                    ),
                  ),
                ),
              if (discountPercentage > 0)
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade200,
                          blurRadius: 4.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${discountPercentage.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                            ),
                          ),
                          Text(
                            'OFF',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 7.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹$price',
                        style: GoogleFonts.poppins(
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                      if (oldPrice > 0) ...[
                        SizedBox(width: 4.w),
                        Text(
                          '₹$oldPrice',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.red.shade300,
                            decorationThickness: 2,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 12.sp,
                          color: Colors.amber,
                        ),
                      ),
                      if (reviewCount > 0) ...[
                        SizedBox(width: 4.w),
                        Text(
                          '($reviewCount)',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 9.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (discountPercentage > 0)
                    Container(
                      margin: EdgeInsets.only(top: 4.h),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_offer,
                            size: 12.sp,
                            color: Colors.red.shade400,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Save ₹${(oldPrice - price).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w500,
                              fontSize: 9.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Provider.of<CartProvider>(context, listen: false)
                            .addToCart({
                          'title': title,
                          'price': price,
                          'image': asset,
                          'quantity': 1,
                        });
                        CustomSnackbar.showSuccess(
                          context: context,
                          message: '$title added to cart',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                      ),
                      child: Text(
                        'Add to Cart',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 11.sp,
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
    );
  }
}
