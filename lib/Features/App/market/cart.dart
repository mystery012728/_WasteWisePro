import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/payment/razer_pay.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutternew/Features/App/market/OGprovidere.dart';
import 'package:flutternew/Features/App/market/payment.dart';

class CartPage extends StatefulWidget {
  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color lightGreen = const Color(0xFF81C784);
  bool _isLoading = false;

  Future<void> _handleRemoveItem(BuildContext context,
      CartProvider cartProvider, int index, Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    try {
      await cartProvider.removeFromCart(index,
          userId: 'user123'); // Replace with actual user ID
      CustomSnackbar.showSuccess(
        context: context,
        message: '${item['title']} removed from cart',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await cartProvider.addToCart(item,
              userId: 'user123'); // Replace with actual user ID
        },
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateQuantity(BuildContext context,
      CartProvider cartProvider, int index, int newQuantity) async {
    setState(() => _isLoading = true);
    try {
      await cartProvider.updateQuantity(index, newQuantity,
          userId: 'user123'); // Replace with actual user ID
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: primaryGreen,
            title: Text(
              'Cart',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          body: Column(
            children: [
              if (!cartProvider.hasShownTutorial &&
                  cartProvider.cartItems.isNotEmpty)
                _buildTutorialBar(context),
              Expanded(
                child: cartProvider.cartItems.isEmpty
                    ? Center(
                  child: Text(
                    'Your cart is empty.',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: primaryGreen,
                    ),
                  ).animate().fadeIn().scale(),
                )
                    : ListView.builder(
                  itemCount: cartProvider.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartProvider.cartItems[index];
                    return Dismissible(
                      key: Key(item['title']),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20.0),
                        color: Colors.red,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => _handleRemoveItem(
                          context, cartProvider, index, item),
                      child: Card(
                        margin: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: item['image'],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      CircularProgressIndicator(
                                        valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            primaryGreen),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.error,
                                          color: primaryGreen),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: primaryGreen,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Price: ₹${NumberFormat('#,##0').format(item['price'])}",
                                      style: GoogleFonts.poppins(
                                          color: lightGreen),
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.remove,
                                              color: primaryGreen),
                                          onPressed: () =>
                                              _handleUpdateQuantity(
                                                  context,
                                                  cartProvider,
                                                  index,
                                                  item['quantity'] - 1),
                                        ),
                                        Text(
                                          '${item['quantity']}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: primaryGreen,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.add,
                                              color: primaryGreen),
                                          onPressed: () =>
                                              _handleUpdateQuantity(
                                                  context,
                                                  cartProvider,
                                                  index,
                                                  item['quantity'] + 1),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn().slideX();
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            width: screenSize.width,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total:",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    Text(
                      "₹${NumberFormat('#,##0').format(cartProvider.totalPrice)}",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cartProvider.cartItems.isEmpty || _isLoading
                        ? null
                        : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddressScreen(
                            productInfo: {
                              'price': cartProvider.totalPrice,
                              'cartItems': cartProvider.cartItems,
                              'image':
                              cartProvider.cartItems.first['image'],
                              'title':
                              '${cartProvider.cartItems.length} items in cart',
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Proceed to Pay',
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
          ).animate().fadeIn().slideY(),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTutorialBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      color: lightGreen.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryGreen),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Swipe left to remove items from your cart',
              style: GoogleFonts.poppins(color: primaryGreen),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: primaryGreen),
            onPressed: () async {
              await Provider.of<CartProvider>(context, listen: false)
                  .setTutorialShown();
            },
          ),
        ],
      ),
    ).animate().fadeIn().slideY();
  }
}
