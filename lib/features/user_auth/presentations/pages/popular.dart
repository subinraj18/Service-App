import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PopularItemsPage extends StatefulWidget {
  const PopularItemsPage({Key? key}) : super(key: key);

  @override
  State<PopularItemsPage> createState() => _PopularItemsPageState();
}

class _PopularItemsPageState extends State<PopularItemsPage> {
  // Fetch popular items based on "PickedUp" status
  Future<Map<String, List<Map<String, dynamic>>>> _getPopularItems() async {
    // Helper function to calculate popularity from a snapshot
    Map<String, Map<String, dynamic>> _calculatePopularity(QuerySnapshot snapshot, String serviceName) {
      Map<String, Map<String, dynamic>> productPopularity = {};

      for (var doc in snapshot.docs) {
        var order = doc.data() as Map<String, dynamic>;
        var products = List<Map<String, dynamic>>.from(order['products'] ?? []);
        for (var product in products) {
          String name = product['name'] ?? 'Unknown Product';
          String status = product['status']?.toString().toLowerCase() ?? '';
          String image = product['image'] ?? '';
          num price = product['price'] ?? 0;

          if (status == 'pickedup') {
            if (productPopularity.containsKey(name)) {
              productPopularity[name]!['popularity'] += 1;
            } else {
              productPopularity[name] = {
                'popularity': 1,
                'image': image,
                'price': price,
                'service': serviceName,
              };
            }
          }
        }
      }
      return productPopularity;
    }

    // Fetch all orders
    final storeOrders = await FirebaseFirestore.instance.collection('storeorders').get();
    final canteenOrders = await FirebaseFirestore.instance.collection('canteenorders').get();
    final cafeteriaOrders = await FirebaseFirestore.instance.collection('cafeteriaorders').get();

    // Calculate popularity
    final storePopularity = _calculatePopularity(storeOrders, 'Store');
    final canteenPopularity = _calculatePopularity(canteenOrders, 'Canteen');
    final cafeteriaPopularity = _calculatePopularity(cafeteriaOrders, 'Cafeteria');

    // Convert to list and sort by popularity
    List<Map<String, dynamic>> getTopItems(Map<String, Map<String, dynamic>> popularityMap, String category) {
      List<Map<String, dynamic>> result = [];
      for (var entry in popularityMap.entries) {
        result.add({
          'name': entry.key,
          ...entry.value,
        });
      }
      result.sort((a, b) => (b['popularity'] as num).compareTo(a['popularity'] as num));
      return result.take(3).toList(); // Top 3 items
    }

    return {
      'Store': getTopItems(storePopularity, 'Store'),
      'Canteen': getTopItems(canteenPopularity, 'Canteen'),
      'Cafeteria': getTopItems(cafeteriaPopularity, 'Cafeteria'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Most Popular',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _getPopularItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          bool hasData = data['Store']!.isNotEmpty ||
              data['Canteen']!.isNotEmpty ||
              data['Cafeteria']!.isNotEmpty;

          if (!hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No popular items yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for our top picks',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBanner(),
                if (data['Store']!.isNotEmpty)
                  _buildServiceSection('Store Favorites', data['Store']!),
                if (data['Canteen']!.isNotEmpty)
                  _buildServiceSection('Canteen Favorites', data['Canteen']!),
                if (data['Cafeteria']!.isNotEmpty)
                  _buildServiceSection('Cafeteria Favorites', data['Cafeteria']!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campus Favorites',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Most loved items across all services',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSection(String title, List<Map<String, dynamic>> products) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProductCards(products),
        ],
      ),
    );
  }

  Widget _buildProductCards(List<Map<String, dynamic>> products) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final p = products[index];
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image with ribbon
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: p['image'] != ''
                              ? Image.network(
                            p['image'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          )
                              : Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Top Pick',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Product details
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From ${p['service']}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${p['price'].toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}