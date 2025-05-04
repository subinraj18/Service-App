import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'canteencart.dart';

class CanteenPage extends StatefulWidget {
  const CanteenPage({super.key});

  @override
  _CanteenPageState createState() => _CanteenPageState();
}

class _CanteenPageState extends State<CanteenPage> with SingleTickerProviderStateMixin {
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Favorite', 'Snacks', 'Meals', 'Beverages', 'Others'];
  List<Map<String, dynamic>> cartItems = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> favoriteProducts = [];
  Map<String, double> productRatings = {};
  bool isLoading = true;

  // Canteen status variables
  bool _isCanteenOpen = false;
  bool _isSuddenClosure = false;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String canteenTimeDocId = 'current_canteen_status';
  late SharedPreferences _prefs;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

    // Load canteen status and start periodic time checks
    _loadCanteenStatus();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 60)); // Check every minute
      if (mounted) _updateStatusBasedOnTime();
      return mounted; // Continue if still mounted
    });
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    await _loadFromCache();
    if (products.isEmpty) {
      await _fetchProducts();
    }
    await _fetchProductRatings();
    await _fetchFavoriteProducts();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final String? productsJson = _prefs.getString('canteen_products');
      if (productsJson != null) {
        final List<dynamic> decoded = jsonDecode(productsJson);
        setState(() {
          products = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } catch (e) {
      print('Error loading canteen products from cache: $e');
    }
  }

  Future<void> _saveToCache(List<Map<String, dynamic>> products) async {
    try {
      final String productsJson = jsonEncode(products);
      await _prefs.setString('canteen_products', productsJson);
    } catch (e) {
      print('Error saving canteen products to cache: $e');
    }
  }

  Future<void> _loadCanteenStatus() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('canteentime').doc(canteenTimeDocId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _isCanteenOpen = data['isCanteenOpen'] as bool? ?? false;
            _isSuddenClosure = data['isSuddenClosure'] as bool? ?? false;
            if (data['openTime'] != null && data['openTime'] is Map) {
              final openTimeData = data['openTime'] as Map;
              _openTime = TimeOfDay(
                hour: openTimeData['hour'] as int? ?? 0,
                minute: openTimeData['minute'] as int? ?? 0,
              );
            }
            if (data['closeTime'] != null && data['closeTime'] is Map) {
              final closeTimeData = data['closeTime'] as Map;
              _closeTime = TimeOfDay(
                hour: closeTimeData['hour'] as int? ?? 0,
                minute: closeTimeData['minute'] as int? ?? 0,
              );
            }
            print('Loaded Canteen Status: Open=$_isCanteenOpen, SuddenClosure=$_isSuddenClosure, OpenTime=$_openTime, CloseTime=$_closeTime');
          });
          _updateStatusBasedOnTime();
        } else {
          print('No data found in document');
        }
      } else {
        print('Document does not exist');
      }
    } catch (e) {
      print('Error loading canteen status: $e');
    }
  }

  void _updateStatusBasedOnTime() {
    if (_isSuddenClosure) {
      print('Canteen is suddenly closed');
      return;
    }

    final now = TimeOfDay.now();
    bool shouldBeOpen = false;

    if (_openTime != null && _closeTime != null) {
      int nowMinutes = now.hour * 60 + now.minute;
      int openMinutes = _openTime!.hour * 60 + _openTime!.minute;
      int closeMinutes = _closeTime!.hour * 60 + _closeTime!.minute;

      if (closeMinutes < openMinutes) {
        shouldBeOpen = nowMinutes >= openMinutes || nowMinutes < closeMinutes;
      } else {
        shouldBeOpen = nowMinutes >= openMinutes && nowMinutes < closeMinutes;
      }
    }

    print('Canteen Open Check: ShouldBeOpen=$shouldBeOpen, CurrentTime=${now.hour}:${now.minute}, OpenTime=$_openTime, CloseTime=$_closeTime');
    if (shouldBeOpen != _isCanteenOpen) {
      setState(() {
        _isCanteenOpen = shouldBeOpen;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductRatings() async {
    try {
      QuerySnapshot reviewsSnapshot = await _firestore.collection('canteenproduct_reviews').get();
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
        double sum = ratings.reduce((a, b) => a + b);
        averages[productId] = double.parse((sum / ratings.length).toStringAsFixed(1));
      });

      setState(() {
        productRatings = averages;
      });
    } catch (e) {
      print('Error fetching canteen product ratings: $e');
    }
  }

  Future<void> _fetchProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('canteenproducts').get();
      setState(() {
        products = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String imageUrl = data['image'] as String? ?? 'https://via.placeholder.com/150';
          if (imageUrl.startsWith('assets/')) {
            imageUrl = 'https://via.placeholder.com/150';
          }
          int quantity = (data['quantity'] as num?)?.toInt() ?? 0;
          print('Fetched Product: ${data['name']}, Quantity: $quantity');
          return {
            'id': doc.id,
            'productId': data['productId'] as String? ?? '',
            'name': data['name'] as String? ?? 'Unknown Product',
            'category': data['category'] as String? ?? 'Others',
            'image': imageUrl,
            'price': (data['price'] as num?)?.toDouble() ?? 0.0,
            'description': data['description'] as String? ?? 'No description',
            'quantity': quantity,
            'status': data['status'] as String? ?? 'Unavailable',
          };
        }).toList();
      });
      await _saveToCache(products);
    } catch (e) {
      print('Error fetching canteen products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load canteen products: $e')));
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
    print('Attempting to add to cart: ${product['name']}, Quantity: ${product['quantity']}, Canteen Open: $_isCanteenOpen');
    if (!_isCanteenOpen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canteen is currently closed')));
      return;
    }

    setState(() {
      int existingIndex = cartItems.indexWhere((item) => item['id'] == product['id']);
      if (existingIndex != -1) {
        int cartQuantity = cartItems[existingIndex]['cartQuantity'] as int? ?? 0;
        int stockQuantity = product['quantity'] as int;
        if (cartQuantity < stockQuantity) {
          cartItems[existingIndex]['cartQuantity'] = cartQuantity + 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No more ${product['name']} available')),
          );
        }
      } else {
        if (product['quantity'] > 0) {
          cartItems.add({...product, 'cartQuantity': 1});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product['name']} is out of stock')),
          );
        }
      }
      print('Cart Items Updated: $cartItems');
    });
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
                  onPressed: _isCanteenOpen
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CanteenCartPage(cartItems: cartItems)),
                    ).then((_) => setState(() {}));
                  }
                      : null,
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '${cartItems.fold(0, (sum, item) => sum + (item['cartQuantity'] as int))}',
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
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Canteen",
                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Order fresh and delicious food",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isCanteenOpen
                              ? [Colors.green.shade300, Colors.green.shade100]
                              : [Colors.red.shade300, Colors.red.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _isCanteenOpen ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
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
                            _isCanteenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCanteenOpen ? "OPEN" : "CLOSED",
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Row(
                    children: categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: selectedCategory == category
                                  ? [Colors.blue.shade400, Colors.blue.shade600]
                                  : [Colors.white, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.blue.shade100, blurRadius: 8, offset: const Offset(0, 3)),
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
              ),
              const SizedBox(height: 24),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: Colors.blue.shade400))
                    : products.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fastfood_outlined, size: 64, color: Colors.blue.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No products available',
                        style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade400),
                        child: Text('Refresh', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                )
                    : filteredProducts.isEmpty
                    ? Center(
                  child: Text(
                    selectedCategory == 'Favorite'
                        ? 'No favorite products yet'
                        : 'No products in this category',
                    style: GoogleFonts.poppins(color: Colors.black54),
                  ),
                )
                    : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
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
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    bool isAvailable = (product['quantity'] as int) > 0;
    String productId = product['id'] as String;
    double rating = productRatings[productId] ?? 0.0;
    bool isFavorite = favoriteProducts.any((p) => p['id'] == product['id']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.blue.shade100, blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showProductDialog(product),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(color: Colors.grey.shade100),
                            child: Image.network(
                              product['image'] as String,
                              height: double.infinity,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ?? 1)
                                        : null,
                                    color: Colors.blue.shade400,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 40,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (!isAvailable)
                            Container(
                              height: double.infinity,
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.6),
                              child: Center(
                                child: Text(
                                  'SOLD OUT',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                product['name'] as String,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                if (rating > 0) ...[
                                  ...List.generate(
                                    5,
                                        (index) => Icon(
                                      index < rating.floor()
                                          ? Icons.star
                                          : (index < rating ? Icons.star_half : Icons.star_border),
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ] else
                                  Text(
                                    'No ratings',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                                  ),
                              ],
                            ),
                            Flexible(
                              child: Text(
                                '₹${(product['price'] as double).toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.blue.shade600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
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
      ),
    );
  }

  void _showProductDialog(Map<String, dynamic> product) {
    String productId = product['id'] as String;
    double rating = productRatings[productId] ?? 0.0;
    bool isFavorite = favoriteProducts.any((p) => p['id'] == product['id']);
    print('Showing Dialog for: ${product['name']}, Quantity: ${product['quantity']}, Canteen Open: $_isCanteenOpen');

    showDialog(
      context: context,
      builder: (context) {
        bool canAddToCart = (product['quantity'] as int) > 0 && _isCanteenOpen;
        print('Can Add to Cart: $canAddToCart');

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
                    product['image'] as String,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                            color: Colors.blue.shade400,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product['name'] as String,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: [
                        if (rating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
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
                            _showProductDialog(product);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rating > 0)
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.floor()
                            ? Icons.star
                            : (index < rating ? Icons.star_half : Icons.star_border),
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Available Quantity: ${product['quantity']}',
                  style: GoogleFonts.poppins(
                    color: (product['quantity'] as int) > 0 ? Colors.green.shade600 : Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product['description'] as String,
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Text(
                  '₹${(product['price'] as double).toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
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
                        gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: (product['quantity'] as int) > 0 && _isCanteenOpen
                            ? () {
                          print('Add to Cart Clicked for ${product['name']}');
                          _addToCart(product);
                          Navigator.of(context).pop();
                        }
                            : null,
                        // Temporary workaround to force button clickable (uncomment to test):
                        // onPressed: () {
                        //   print('Add to Cart Clicked (Forced) for ${product['name']}');
                        //   _addToCart(product);
                        //   Navigator.of(context).pop();
                        // },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: (product['quantity'] as int) > 0 && _isCanteenOpen
                                ? Colors.white
                                : Colors.grey.shade400,
                          ),
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