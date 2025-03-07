import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartProvider with ChangeNotifier {
  List<Map<String, dynamic>> _cartItems = [];
  bool _hasShownTutorial = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> get cartItems => _cartItems;
  bool get hasShownTutorial => _hasShownTutorial;

  Future<void> _saveToFirestore(String userId) async {
    try {
      await _firestore.collection('cart_details').doc(userId).set({
        'items': _cartItems,
        'total': totalPrice,
        'lastUpdated': FieldValue.serverTimestamp(),
        'hasShownTutorial': _hasShownTutorial,
      });
    } catch (e) {
      print('Error saving cart to Firestore: $e');
    }
  }

  Future<void> loadFromFirestore(String userId) async {
    try {
      final doc = await _firestore.collection('cart_details').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          if (data['items'] != null) {
            _cartItems = List<Map<String, dynamic>>.from(data['items']);
          }
          _hasShownTutorial = data['hasShownTutorial'] ?? false;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading cart from Firestore: $e');
    }
  }

  Future<void> addToCart(Map<String, dynamic> item, {String? userId}) async {
    int existingIndex =
    _cartItems.indexWhere((cartItem) => cartItem['title'] == item['title']);
    if (existingIndex != -1) {
      _cartItems[existingIndex]['quantity'] += 1;
    } else {
      _cartItems.add({...item, 'quantity': 1});
    }
    if (userId != null) {
      await _saveToFirestore(userId);
    }
    notifyListeners();
  }

  double get totalPrice {
    return _cartItems.fold(
        0, (total, item) => total + (item['price'] * item['quantity']));
  }

  Future<void> clearCart({String? userId}) async {
    _cartItems.clear();
    if (userId != null) {
      await _saveToFirestore(userId);
    }
    notifyListeners();
  }

  Future<void> removeFromCart(int index, {String? userId}) async {
    _cartItems.removeAt(index);
    if (userId != null) {
      await _saveToFirestore(userId);
    }
    notifyListeners();
  }

  Future<void> updateQuantity(int index, int quantity, {String? userId}) async {
    if (quantity > 0) {
      _cartItems[index]['quantity'] = quantity;
    } else {
      _cartItems.removeAt(index);
    }
    if (userId != null) {
      await _saveToFirestore(userId);
    }
    notifyListeners();
  }

  Future<void> setTutorialShown({String? userId}) async {
    _hasShownTutorial = true;
    if (userId != null) {
      await _saveToFirestore(userId);
    }
    notifyListeners();
  }

  Future<void> syncWithFirestore(String userId) async {
    await loadFromFirestore(userId);
    await _saveToFirestore(userId);
  }
}
