import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'caferteriacart.dart';

class CafeteriaPage extends StatefulWidget {
  const CafeteriaPage({super.key});

  @override
  _CafeteriaPageState createState() => _CafeteriaPageState();
}

class _CafeteriaPageState extends State<CafeteriaPage> with SingleTickerProviderStateMixin {
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Favorite', 'Snacks', 'Meals', 'Beverages', 'Others']; // Added 'Favorite'
  List<Map<String, dynamic>> cartItems = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> favoriteProducts = []; // Added for favorites
  Map<String, double> productRatings = {};
  bool isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    await _fetchProducts();
    await _fetchProductRatings();
    await _fetchFavoriteProducts(); // Added to load favorites

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductRatings() async {
    try {
      print('Fetching product ratings from cafeteriaproduct_reviews...');
      QuerySnapshot reviewsSnapshot = await FirebaseFirestore.instance.collection('cafeteriaproduct_reviews').get();
      print('Fetched ${reviewsSnapshot.docs.length} cafeteria reviews');

      Map<String, List<double>> ratingsByProduct = {};
      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final productId = data['productId'] as String?;
        final rating = (data['rating'] as num?)?.toDouble();

        if (productId == null || rating == null) {
          print('Skipping review with missing productId or rating: $data');
          continue;
        }

        ratingsByProduct.putIfAbsent(productId, () => []).add(rating);
        print('Review found for cafeteria productId: $productId with rating: $rating');
      }

      Map<String, double> averages = {};
      ratingsByProduct.forEach((productId, ratings) {
        double sum = ratings.reduce((a, b) => a + b);
        averages[productId] = double.parse((sum / ratings.length).toStringAsFixed(1));
        print('Average rating for cafeteria productId: $productId: ${averages[productId]}');
      });

      setState(() {
        productRatings = averages;
      });
    } catch (e) {
      print('Error fetching cafeteria product ratings: $e');
    }
  }

  Future<void> _fetchProducts() async {
    try {
      print('Fetching cafeteria products...');
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('cafeteriaproducts').get();
      print('Fetched ${snapshot.docs.length} cafeteria products');

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
            'quantity': data['quantity'] ?? 0,
            'status': data['status'] ?? 'Unavailable',
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching cafeteria products: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cafeteria products: $e')),
      );
    }
  }

  Future<void> _fetchFavoriteProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

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
      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .set({
        'favorites': favoriteProducts.map((p) => p['id']).toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating favorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: $e')),
      );
      await _fetchFavoriteProducts(); // Revert state on error
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      int existingIndex = cartItems.indexWhere((item) => item['id'] == product['id']);
      if (existingIndex != -1) {
        if (cartItems[existingIndex]['quantity'] < product['quantity']) {
          cartItems[existingIndex]['quantity']++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No more ${product['name']} available')),
          );
        }
      } else {
        if (product['quantity'] > 0) {
          cartItems.add({...product, 'quantity': 1});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product['name']} is out of stock')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredProducts = selectedCategory == 'All'
        ? products
        : selectedCategory == 'Favorite'
        ? favoriteProducts // Filter for favorites
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
                      MaterialPageRoute(
                        builder: (context) => CafeteriaCartPage(cartItems: cartItems),
                      ),
                    ).then((_) => setState(() {})); // Refresh state after cart
                  },
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
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
            colors: [Colors.green.shade50, Colors.white],
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
                      "Cafeteria",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Order fresh and delicious food",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
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
                                  ? [Colors.green.shade400, Colors.green.shade600]
                                  : [Colors.white, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.shade100,
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
              ),
              const SizedBox(height: 24),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: Colors.green.shade400))
                    : products.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fastfood_outlined, size: 64, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No products available',
                        style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade400),
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
    bool isAvailable = product['quantity'] > 0;
    String productId = product['id'];
    double rating = productRatings[productId] ?? 0.0;
    bool isFavorite = favoriteProducts.any((p) => p['id'] == product['id']); // Added for favorites

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.green.shade100, blurRadius: 8, offset: const Offset(0, 3)),
        ],
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
                              product['image'],
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
                                    color: Colors.green.shade400,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading image for ${product['name']}: $error');
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
                                product['name'],
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
                                '₹${product['price'].toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.green.shade600,
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
    String productId = product['id'];
    double rating = productRatings[productId] ?? 0.0;
    bool isFavorite = favoriteProducts.any((p) => p['id'] == product['id']); // Added for favorites

    showDialog(
      context: context,
      builder: (context) {
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
                      return Container(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                            color: Colors.green.shade400,
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
                            Navigator.pop(context); // Close dialog
                            _showProductDialog(product); // Reopen with updated state
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
                    color: product['quantity'] > 0 ? Colors.green.shade600 : Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
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
                        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: product['quantity'] > 0
                            ? () {
                          _addToCart(product);
                          Navigator.of(context).pop();
                        }
                            : null,
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
                            color: product['quantity'] > 0 ? Colors.white : Colors.grey.shade400,
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