import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miniproject/features/user_auth/presentations/pages/storecart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with SingleTickerProviderStateMixin {
  String selectedCategory = 'All';
  final List<String> categories = [
    'All',
    'Favorite',
    'Uniform',
    'Books',
    'Stationary',
    'Others',
  ];
  List<Map<String, dynamic>> favoriteProducts = [];
  List<Map<String, dynamic>> cartItems = [];
  List<Map<String, dynamic>> products = [];
  Map<String, double> productRatings = {};
  bool isLoading = true;
  bool _isStoreOpen = false;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String storeTimeDocId = 'current_store_status';
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    await _fetchProducts();
    await _fetchProductRatings();
    await _fetchFavoriteProducts();
    await _fetchStoreStatus();

    if (products.isEmpty && mounted) {
      await _loadFromCache(); // Fallback to cache if Firestore fetch fails
      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products available')),
        );
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> _clearCacheAndReload() async {
    await _prefs.remove('store_products');
    await _loadData();
  }

  Future<void> _loadFromCache() async {
    try {
      final String? productsJson = _prefs.getString('store_products');
      if (productsJson != null) {
        final List<dynamic> decoded = jsonDecode(productsJson);
        setState(() {
          products = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } catch (e) {
      print('Error loading from cache: $e');
    }
  }

  Future<void> _saveToCache(List<Map<String, dynamic>> products) async {
    try {
      final String productsJson = jsonEncode(products);
      await _prefs.setString('store_products', productsJson);
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  Future<void> _fetchStoreStatus() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('storetime').doc(storeTimeDocId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _isStoreOpen = data['isStoreOpen'] ?? false;
          if (data['openTime'] != null) {
            _openTime = TimeOfDay(hour: data['openTime']['hour'], minute: data['openTime']['minute']);
          }
          if (data['closeTime'] != null) {
            _closeTime = TimeOfDay(hour: data['closeTime']['hour'], minute: data['closeTime']['minute']);
          }
        });
      }
    } catch (e) {
      print('Error fetching store status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load store status: $e')));
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductRatings() async {
    try {
      QuerySnapshot reviewsSnapshot = await _firestore.collection('storeproduct_reviews').get();
      Map<String, List<double>> ratingsByProduct = {};

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final productId = data['productId'] as String?;
        final rating = (data['rating'] as num?)?.toDouble();
        if (productId == null || rating == null) continue;
        ratingsByProduct.putIfAbsent(productId, () => []).add(rating);
      }

      Map<String, double> averages = {};
      ratingsByProduct.forEach((productId, ratings) {
        double avg = ratings.reduce((a, b) => a + b) / ratings.length;
        averages[productId] = double.parse(avg.toStringAsFixed(1));
      });

      setState(() => productRatings = averages);
    } catch (e) {
      print('Error fetching product ratings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load ratings: $e')));
      }
    }
  }

  Future<void> _fetchProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('storeproducts').get();
      setState(() {
        products = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String imageUrl = data['image'] ?? 'https://via.placeholder.com/150';
          if (imageUrl.startsWith('assets/')) {
            imageUrl = 'https://via.placeholder.com/150';
          }
          return {
            'id': doc.id,
            'productId': data['productId'],
            'name': data['name'] ?? 'Unknown Product',
            'category': data['category'] ?? 'Others',
            'image': imageUrl,
            'price': (data['price'] ?? 0.0).toDouble(),
            'description': data['description'] ?? 'No description',
          };
        }).toList();
      });
      await _saveToCache(products); // Save to cache after fetching
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load products: $e')));
      }
    }
  }

  Future<void> _fetchFavoriteProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('students').doc(user.uid).get();
      if (userDoc.exists) {
        List<dynamic> favoriteIds = userDoc.get('favorites') ?? [];
        setState(() {
          favoriteProducts = products.where((product) => favoriteIds.contains(product['id'])).toList();
        });
      }
    } catch (e) {
      print('Error fetching favorite products: $e');
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (favoriteProducts.any((p) => p['id'] == product['id'])) {
        favoriteProducts.removeWhere((p) => p['id'] == product['id']);
      } else {
        favoriteProducts.add(product);
      }
    });

    try {
      await _firestore.collection('students').doc(user.uid).set({
        'favorites': favoriteProducts.map((p) => p['id']).toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update favorites: $e')));
      }
      await _fetchFavoriteProducts();
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      int existingIndex = cartItems.indexWhere((item) => item['id'] == product['id']);
      if (existingIndex != -1) {
        cartItems[existingIndex]['quantity'] = (cartItems[existingIndex]['quantity'] ?? 0) + 1;
      } else {
        cartItems.add({...product, 'quantity': 1});
      }
    });
  }

  void _showStoreScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Store Schedule', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${_isStoreOpen ? "Open" : "Closed"}',
              style: GoogleFonts.poppins(
                color: _isStoreOpen ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Open Time: ${_openTime?.format(context) ?? "Not set"}',
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 10),
            Text(
              'Close Time: ${_closeTime?.format(context) ?? "Not set"}',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredProducts = selectedCategory == 'All'
        ? products
        : selectedCategory == 'Favorite'
        ? favoriteProducts
        : products.where((product) => product['category'] == selectedCategory).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.black87),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CartPage(cartItems: cartItems)),
                    ).then((_) => setState(() {}));
                  },
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cartItems.length}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Store",
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Find everything you need",
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showStoreScheduleDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isStoreOpen
                              ? [Colors.green.shade300, Colors.green.shade100]
                              : [Colors.red.shade300, Colors.red.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _isStoreOpen ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isStoreOpen ? Icons.store : Icons.store_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isStoreOpen ? "OPEN" : "CLOSED",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: selectedCategory == category
                                    ? [Colors.orange.shade400, Colors.orange.shade600]
                                    : [Colors.white, Colors.white],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.shade100,
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setState(() => selectedCategory = category),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Text(
                                    category,
                                    style: GoogleFonts.poppins(
                                      color: selectedCategory == category ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: isLoading
                        ? Center(child: CircularProgressIndicator(color: Colors.orange.shade400))
                        : products.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 64, color: Colors.orange.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No products available',
                            style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade400),
                            child: Text('Refresh', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    )
                        : filteredProducts.isEmpty
                        ? Center(
                      child: Text(
                        'No products in this category',
                        style: GoogleFonts.poppins(color: Colors.black54),
                      ),
                    )
                        : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(filteredProducts[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    bool isFavorite = favoriteProducts.any((p) => p['id'] == product['id']);
    double rating = productRatings[product['id']] ?? 0.0;

    return GestureDetector(
      onTap: () => _showProductDetailsDialog(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.orange.shade100, blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      child: Image.network(
                        product['image'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              product['name'],
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rating > 0)
                            Row(
                              children: [
                                ...List.generate(5, (index) => Icon(
                                  index < rating.floor()
                                      ? Icons.star
                                      : (index < rating ? Icons.star_half : Icons.star_border),
                                  color: Colors.amber,
                                  size: 16,
                                )),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          else
                            Text(
                              'No ratings yet',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                            ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              '₹${product['price'].toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                  color: Colors.green.shade600, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(0.01),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                      size: 18,
                    ),
                    onPressed: () => _toggleFavorite(product),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetailsDialog(Map<String, dynamic> product) {
    double rating = productRatings[product['id']] ?? 0.0;
    bool isFavorite = favoriteProducts.any((p) => p['id'] == product['id']);

    // Update cache with viewed product details
    _saveToCache(products);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    product['image'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product['name'],
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: [
                        if (rating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                          onPressed: () {
                            _toggleFavorite(product);
                            Navigator.pop(context);
                            _showProductDetailsDialog(product);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rating > 0)
                  Row(
                    children: List.generate(5, (index) => Icon(
                      index < rating.floor()
                          ? Icons.star
                          : (index < rating ? Icons.star_half : Icons.star_border),
                      color: Colors.amber,
                      size: 20,
                    )),
                  ),
                const SizedBox(height: 8),
                Text(
                  product['description'],
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Text(
                  '₹${product['price'].toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade600),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close', style: GoogleFonts.poppins(color: Colors.black54)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade600]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          _addToCart(product);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}