import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch products from 'hot_deals_products' collection
  Stream<List<Map<String, dynamic>>> getHotDealsProducts() {
    return _db
        .collection('hot_deals_products')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => doc.data())
        .toList());
  }
}
