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
          icon: Icon(Icons.filter_list, color: Colors.teal.shade700),
          onPressed: _showFilterDialog,
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search, color: Colors.teal.shade700),
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                onPressed: () {
                  _searchController.clear();
                },
              ),
            ),
            onSubmitted: _handleSearch,
            textInputAction: TextInputAction.search,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart, color: Colors.teal.shade700),
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
        const SizedBox(height: 24),
        _buildCategoriesSection(context),
        const SizedBox(height: 24),
        _buildHotDealsSection(context),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade400,
                  Colors.teal.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade200.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eco-Friendly Shopping',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Discover sustainable products that make a difference',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Categories',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                title: 'Recycled Crafts',
                icon: Icons.recycling,
                page: RecycledProductsPage(),
                color: Colors.blue.shade400,
              ),
              _buildCategoryCard(
                context,
                title: 'Recycled Electronics',
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
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 120,
                color: color.withOpacity(0.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 40, color: color),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.8),
                    ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Hot Deals',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
            return Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 380,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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

                      final double discountPercentage = oldPrice > 0
                          ? ((oldPrice - price) / oldPrice) * 100
                          : 0;

                      final double rating = (product['rating'] != null)
                          ? (product['rating'] is int
                          ? (product['rating'] as int).toDouble()
                          : (product['rating'] as double))
                          : 0.0;

                      final int reviewCount =
                          product['reviewCount'] as int? ?? 0;

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
                ));
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
      width: 250,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: asset,
                  height: 160,
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
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade100,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (discountPercentage > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
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
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'OFF',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .scale(duration: 300.ms, curve: Curves.elasticOut)
                          .then()
                          .shake(duration: 200.ms, delay: 300.ms),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹$price',
                      style: GoogleFonts.poppins(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    if (oldPrice > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '₹$oldPrice',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red.shade300,
                          decorationThickness: 2,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ...List.generate(
                      5,
                          (index) => Icon(
                        index < rating.round() ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                    if (reviewCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($reviewCount)',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                if (discountPercentage > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          size: 16,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Save ₹${(oldPrice - price).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      'Add to Cart',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
