import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductAlertsPage extends StatefulWidget {
  const ProductAlertsPage({Key? key}) : super(key: key);

  @override
  _ProductAlertsPageState createState() => _ProductAlertsPageState();
}

class _ProductAlertsPageState extends State<ProductAlertsPage> {
  static const String ORDER_STATUS_PENDING = 'pending';
  static const String ORDER_STATUS_COMPLETED = 'completed';
  static const String PRODUCT_STATUS_PREPARING = 'preparing';
  static const String PRODUCT_STATUS_READY = 'ready';
  static const String PRODUCT_STATUS_PICKEDUP = 'pickedup';

  String _selectedCategory = 'store';
  final ScrollController _scrollController = ScrollController();
  Map<String, bool> _reviewStatusCache = {};

  @override
  void initState() {
    super.initState();
    _preloadReviewStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _preloadReviewStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final collectionName = _selectedCategory == 'store'
          ? 'storeproduct_reviews'
          : (_selectedCategory == 'canteen' ? 'canteenproduct_reviews' : 'cafeteriaproduct_reviews');

      final reviewSnapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('userId', isEqualTo: user.uid)
          .get();

      setState(() {
        for (var doc in reviewSnapshot.docs) {
          final data = doc.data();
          final key = "${data['orderId']}_${data['productName']}";
          _reviewStatusCache[key] = true;
        }
      });
    } catch (e) {
      print('Error preloading review status: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _getOrdersStream(String category) {
    final user = FirebaseAuth.instance.currentUser;

    if (category == 'store') {
      return FirebaseFirestore.instance
          .collection('storeorders')
          .where('userId', isEqualTo: user?.uid)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'category': category,
            'documentId': doc.id,
            'orderId': data['orderId'] ?? doc.id,
          };
        }).toList();
      });
    } else if (category == 'canteen') {
      return FirebaseFirestore.instance
          .collection('canteenorders')
          .where('userId', isEqualTo: user?.uid)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'category': category,
            'documentId': doc.id,
            'orderId': data['orderId'] ?? doc.id,
          };
        }).toList();
      });
    } else {
      return FirebaseFirestore.instance
          .collection('cafeteriaorders')
          .where('userId', isEqualTo: user?.uid)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'category': category,
            'documentId': doc.id,
            'orderId': data['orderId'] ?? doc.id,
          };
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            floating: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 60),
                    _buildCategoryTabs(),
                  ],
                ),
              ),
            ),
            title: const Text(
              'My Orders',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getOrdersStream(_selectedCategory),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No orders found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final sortedData = snapshot.data!
                ..sort((a, b) {
                  final aTime = (a['timestamp'] as Timestamp).toDate();
                  final bTime = (b['timestamp'] as Timestamp).toDate();
                  return bTime.compareTo(aTime);
                });

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildOrderCard(sortedData[index]),
                  childCount: sortedData.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(child: _buildCategoryTab('Store', 'store')),
          Expanded(child: _buildCategoryTab('Canteen', 'canteen')),
          Expanded(child: _buildCategoryTab('Cafeteria', 'cafeteria')),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String title, String category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _preloadReviewStatus();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (category == 'store'
              ? Colors.orange.shade400
              : (category == 'cafeteria' ? Colors.green.shade400 : Colors.blue.shade400))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final products = List<Map<String, dynamic>>.from(order['products']);
    final timestamp = (order['timestamp'] as Timestamp).toDate();
    final String orderStatus = order['status'] ?? ORDER_STATUS_PENDING;
    final String orderStatusLower = orderStatus.toLowerCase();

    // Determine the effective status for the order based on the first product's status
    final String firstProductStatus = products.isNotEmpty
        ? (products[0]['productStatus'] ?? products[0]['status'] ?? 'Processing')
        : 'Processing';
    final String productStatusLower = firstProductStatus.toLowerCase();

    bool isPickedUp = productStatusLower == PRODUCT_STATUS_PICKEDUP.toLowerCase() ||
        productStatusLower == 'picked up' ||
        orderStatusLower == ORDER_STATUS_COMPLETED.toLowerCase();
    bool isReady = productStatusLower == PRODUCT_STATUS_READY.toLowerCase() && !isPickedUp;
    bool isProcessing = !isPickedUp && !isReady;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order['orderId'] ?? order['documentId'].toString().substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: order['category'] == 'store'
                            ? Colors.blue.shade100
                            : (order['category'] == 'canteen'
                            ? Colors.orange.shade100
                            : Colors.green.shade100),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order['category'] == 'store'
                            ? 'Store'
                            : (order['category'] == 'canteen' ? 'Canteen' : 'Cafeteria'),
                        style: TextStyle(
                          color: order['category'] == 'store'
                              ? Colors.blue.shade900
                              : (order['category'] == 'canteen'
                              ? Colors.orange.shade900
                              : Colors.green.shade900),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy • HH:mm').format(timestamp),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPickedUp
                            ? Colors.green.shade100
                            : (isReady ? Colors.orange.shade100 : Colors.blue.shade100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPickedUp ? 'Picked Up' : (isReady ? 'Ready' : 'Processing'),
                        style: TextStyle(
                          color: isPickedUp
                              ? Colors.green[700]
                              : (isReady ? Colors.orange[700] : Colors.blue[700]),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductItem(products[index], orderStatus, order['orderId']),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₹${order['totalPrice'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(Map<String, dynamic> product, String orderId) {
    double rating = 3.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Review ${product['name']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rate your experience:'),
                    Slider(
                      value: rating,
                      min: 1.0,
                      max: 5.0,
                      divisions: 4,
                      label: rating.toString(),
                      onChanged: (value) {
                        setState(() {
                          rating = value;
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        labelText: 'Your comments',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade400),
                  child: const Text('Submit', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    _submitReview(product, rating, commentController.text, orderId);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReview(Map<String, dynamic> product, double rating, String comment, String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      QuerySnapshot studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      String username = 'Anonymous';
      if (studentSnapshot.docs.isNotEmpty) {
        Map<String, dynamic> studentData = studentSnapshot.docs.first.data() as Map<String, dynamic>;
        username = studentData['username'] ?? studentData['etlabName'] ?? user.displayName ?? user.email!.split('@')[0];
      } else if (user.displayName != null && user.displayName!.isNotEmpty) {
        username = user.displayName!;
      } else if (user.email != null) {
        username = user.email!.split('@')[0];
      }

      final collectionName = _selectedCategory == 'store'
          ? 'storeproduct_reviews'
          : (_selectedCategory == 'canteen' ? 'canteenproduct_reviews' : 'cafeteriaproduct_reviews');

      if (_selectedCategory == 'store') {
        QuerySnapshot productSnapshot = await FirebaseFirestore.instance
            .collection('storeproducts')
            .where('name', isEqualTo: product['name'])
            .limit(1)
            .get();

        if (productSnapshot.docs.isNotEmpty) {
          final productDocId = productSnapshot.docs.first.id;
          await FirebaseFirestore.instance.collection(collectionName).add({
            'userId': user.uid,
            'userName': username,
            'productName': product['name'],
            'productId': productDocId,
            'rating': rating,
            'comment': comment,
            'timestamp': FieldValue.serverTimestamp(),
            'category': _selectedCategory,
            'orderId': orderId,
          });
        } else {
          await FirebaseFirestore.instance.collection(collectionName).add({
            'userId': user.uid,
            'userName': username,
            'productName': product['name'],
            'productId': product['id'] ?? '',
            'rating': rating,
            'comment': comment,
            'timestamp': FieldValue.serverTimestamp(),
            'category': _selectedCategory,
            'orderId': orderId,
          });
        }
      } else {
        await FirebaseFirestore.instance.collection(collectionName).add({
          'userId': user.uid,
          'userName': username,
          'productName': product['name'],
          'productId': product['id'] ?? '',
          'rating': rating,
          'comment': comment,
          'timestamp': FieldValue.serverTimestamp(),
          'category': _selectedCategory,
          'orderId': orderId,
        });
      }

      if (mounted) {
        setState(() {
          _reviewStatusCache['${orderId}_${product['name']}'] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your review!')),
        );
      }
    } catch (e) {
      print('Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting review: $e')),
        );
      }
    }
  }

  bool _hasReviewed(String productName, String orderId) {
    final key = '${orderId}_$productName';
    return _reviewStatusCache[key] ?? false;
  }

  Widget _buildProductItem(Map<String, dynamic> product, String orderStatus, String orderId) {
    final String productStatus = product['productStatus'] ?? product['status'] ?? 'Processing';
    final String productStatusLower = productStatus.toLowerCase();
    final String orderStatusLower = orderStatus.toLowerCase();

    bool isPickedUp = productStatusLower == PRODUCT_STATUS_PICKEDUP.toLowerCase() ||
        productStatusLower == 'picked up' ||
        orderStatusLower == ORDER_STATUS_COMPLETED.toLowerCase();
    bool isReady = productStatusLower == PRODUCT_STATUS_READY.toLowerCase() && !isPickedUp;
    bool hasReviewed = _hasReviewed(product['name'], orderId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPickedUp ? Colors.green.shade50 : (isReady ? Colors.orange.shade50 : Colors.white),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              product['image'],
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey.shade400,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quantity: ${product['quantity']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPickedUp
                        ? Colors.green.shade100
                        : (isReady ? Colors.orange.shade100 : Colors.blue.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPickedUp ? 'Picked Up' : (isReady ? 'Ready' : 'Processing'),
                    style: TextStyle(
                      color: isPickedUp
                          ? Colors.green[700]
                          : (isReady ? Colors.orange[700] : Colors.blue[700]),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '₹${(product['price'] * product['quantity']).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (isPickedUp && !hasReviewed)
                IconButton(
                  icon: const Icon(
                    Icons.rate_review,
                    color: Colors.amber,
                    size: 24,
                  ),
                  onPressed: () => _showReviewDialog(product, orderId),
                  tooltip: 'Leave a review',
                ),
            ],
          ),
        ],
      ),
    );
  }
}