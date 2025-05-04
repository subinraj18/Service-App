import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CafeteriaAnalysisPage extends StatefulWidget {
  const CafeteriaAnalysisPage({Key? key}) : super(key: key);

  @override
  _CafeteriaAnalysisPageState createState() => _CafeteriaAnalysisPageState();
}

class _CafeteriaAnalysisPageState extends State<CafeteriaAnalysisPage>
    with SingleTickerProviderStateMixin {
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Snacks', 'Meals', 'Beverages', 'Others'];
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  Map<String, List<Map<String, dynamic>>> productReviews = {};

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProductsWithReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductsWithReviews() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('Fetching products from cafeteriaproducts...');
      QuerySnapshot productSnapshot =
      await FirebaseFirestore.instance.collection('cafeteriaproducts').get();
      print('Fetched ${productSnapshot.docs.length} products');

      print('Fetching reviews from cafeteriaproduct_reviews...');
      QuerySnapshot reviewSnapshot = await FirebaseFirestore.instance
          .collection('cafeteriaproduct_reviews')
          .get();
      print('Fetched ${reviewSnapshot.docs.length} reviews');

      // Process products first, using document ID as the primary key
      Map<String, Map<String, dynamic>> productMap = {};
      for (var doc in productSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String productId = doc.id; // Using Firestore document ID

        productMap[productId] = {
          'id': productId,
          'name': data['name'] ?? 'Unknown Product (${doc.id})',
          'category': data['category'] ?? 'Others',
          'image': data['image'] ?? '', // Expecting a Firebase Storage URL
          'price': (data['price'] ?? 0.0).toDouble(),
          'quantity': data['quantity'] ?? 0,
          'status': data['status'] ?? 'Available',
          'isTodaySpecial': data['isTodaySpecial'] ?? false,
          'averageRating': 0.0,
          'reviewCount': 0,
        };
        print('Loaded product: $productId - ${productMap[productId]!['name']}');
      }

      // Process reviews and group by product ID
      Map<String, List<Map<String, dynamic>>> reviews = {};
      for (var doc in reviewSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String? productId = data['productId'] as String?;

        if (productId == null || productId.isEmpty) {
          print('Skipping review with null or empty productId: $data');
          continue;
        }

        if (!productMap.containsKey(productId)) {
          print('Review found for missing product $productId. Adding placeholder.');
          productMap[productId] = {
            'id': productId,
            'name': 'Unknown Product ($productId)',
            'category': 'Others',
            'image': '',
            'price': 0.0,
            'quantity': 0,
            'status': 'Unknown',
            'isTodaySpecial': false,
            'averageRating': 0.0,
            'reviewCount': 0,
          };
        }

        reviews.putIfAbsent(productId, () => []).add({
          'reviewId': doc.id,
          'userId': data['userId'],
          'userName': data['userName'] ?? 'Anonymous',
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'comment': data['comment'] ?? 'No comment',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'category': data['category'] ?? 'unknown',
        });
      }

      // Calculate ratings for each product
      reviews.forEach((productId, reviewList) {
        if (productMap.containsKey(productId)) {
          double sum = reviewList.fold(0.0, (sum, review) => sum + review['rating']);
          productMap[productId]!['averageRating'] =
          reviewList.isEmpty ? 0.0 : sum / reviewList.length;
          productMap[productId]!['reviewCount'] = reviewList.length;
          print(
              'Updated $productId - ${productMap[productId]!['name']}: Rating ${productMap[productId]!['averageRating']}, Reviews: ${reviewList.length}');
        }
      });

      setState(() {
        productReviews = reviews;
        products = productMap.values.toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching cafeteria products with reviews: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredProducts = selectedCategory == 'All'
        ? products
        : products.where((product) => product['category'] == selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        title: Text(
          'Cafeteria Analysis',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Products Overview'),
            Tab(text: 'Reviews Analysis'),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green.shade600))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildProductsOverview(filteredProducts),
          _buildReviewsAnalysis(filteredProducts),
        ],
      ),
    );
  }

  Widget _buildProductsOverview(List<Map<String, dynamic>> filteredProducts) {
    filteredProducts.sort((a, b) => b['averageRating'].compareTo(a['averageRating']));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: selectedCategory == category,
                    onSelected: (selected) {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.green.shade200,
                    checkmarkColor: Colors.green.shade700,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
              child: Text('No products in this category',
                  style: GoogleFonts.poppins(color: Colors.black54)))
              : ListView.builder(
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) =>
                _buildProductOverviewCard(filteredProducts[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildProductOverviewCard(Map<String, dynamic> product) {
    double rating = product['averageRating'];
    int reviewCount = product['reviewCount'];
    bool isTodaySpecial = product['isTodaySpecial'] ?? false;

    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _showProductReviews(product),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align content to top to avoid stretching
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: product['image'] != null && product['image'].isNotEmpty
                          ? Image.network(
                        product['image'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported, size: 80),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 80,
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                      )
                          : const Icon(Icons.image_not_supported, size: 80),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis, // Truncate long names
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(5, (index) => Icon(
                                    index < rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 18,
                                  )),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${rating.toStringAsFixed(1)} ($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})',
                                  style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12),
                                  overflow: TextOverflow.ellipsis, // Truncate long rating text
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Category: ${product['category']}',
                                  style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12),
                                  overflow: TextOverflow.ellipsis, // Truncate long category text
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: product['status'] == 'Available'
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                ),
                                child: Text(
                                  product['status'] ?? 'Unknown',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: product['status'] == 'Available'
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '₹${product['price'].toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green.shade600,
                          ),
                          overflow: TextOverflow.ellipsis, // Truncate long price text
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Qty: ${product['quantity']}',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                          overflow: TextOverflow.ellipsis, // Truncate long quantity text
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        Icon(Icons.chevron_right, color: Colors.green.shade400),
                      ],
                    ),
                  ],
                ),
              ),
              if (isTodaySpecial)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "Today's Special",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        )
    );
  }

  void _showProductReviews(Map<String, dynamic> product) {
    List<Map<String, dynamic>> reviews = productReviews[product['id']] ?? [];
    reviews.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  product['image'] != null && product['image'].isNotEmpty
                      ? Image.network(
                    product['image'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported, size: 60),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        width: 60,
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  )
                      : const Icon(Icons.image_not_supported, size: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'],
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Row(
                          children: [
                            ...List.generate(5, (index) => Icon(
                              index < product['averageRating']
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 18,
                            )),
                            const SizedBox(width: 8),
                            Text(
                              '${product['averageRating'].toStringAsFixed(1)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Customer Reviews (${reviews.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: reviews.isEmpty
                    ? Center(
                    child: Text('No reviews yet',
                        style: GoogleFonts.poppins(color: Colors.black54)))
                    : ListView.builder(
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> review = reviews[index];
                    double rating = review['rating'];
                    String userName = review['userName'] ?? 'Anonymous';
                    String comment = review['comment'] ?? 'No comment';
                    Timestamp timestamp = review['timestamp'] ?? Timestamp.now();
                    DateTime date = timestamp.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(userName,
                                    style:
                                    GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(date),
                                  style: GoogleFonts.poppins(
                                      color: Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (index) => Icon(
                                index < rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              )),
                            ),
                            const SizedBox(height: 8),
                            Text(comment, style: GoogleFonts.poppins()),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsAnalysis(List<Map<String, dynamic>> filteredProducts) {
    int totalReviews = 0;
    double overallRating = 0;
    Map<double, int> ratingDistribution = {1.0: 0, 2.0: 0, 3.0: 0, 4.0: 0, 5.0: 0};

    productReviews.forEach((productId, reviews) {
      for (var review in reviews) {
        double rating = review['rating'];
        totalReviews++;
        overallRating += rating;
        double key = rating.floor().toDouble();
        ratingDistribution[key] = (ratingDistribution[key] ?? 0) + 1;
      }
    });

    overallRating = totalReviews > 0 ? overallRating / totalReviews : 0;

    // Get products with "Today's Special" flag
    var todaysSpecials = filteredProducts.where((p) => p['isTodaySpecial'] == true).toList();
    todaysSpecials.sort((a, b) => b['averageRating'].compareTo(a['averageRating']));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Overall Cafeteria Rating',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            overallRating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (index) => Icon(
                                  index < overallRating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 24,
                                )),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Based on $totalReviews reviews',
                                style: GoogleFonts.poppins(color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rating Distribution',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(5, (index) {
                        int starCount = 5 - index;
                        int count = ratingDistribution[starCount.toDouble()] ?? 0;
                        double percentage = totalReviews > 0 ? (count / totalReviews) * 100 : 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '$starCount',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '$count (${percentage.toStringAsFixed(1)}%)',
                                  style: GoogleFonts.poppins(color: Colors.black54),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (todaysSpecials.isNotEmpty) ...[
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Special Items",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ...todaysSpecials.take(5).map((product) => ListTile(
                          leading: product['image'] != null &&
                              product['image'].isNotEmpty
                              ? Image.network(
                            product['image'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, size: 40),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                          )
                              : const Icon(Icons.image_not_supported, size: 40),
                          title: Text(
                            product['name'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Row(
                            children: [
                              ...List.generate(5, (index) => Icon(
                                index < product['averageRating']
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 14,
                              )),
                              const SizedBox(width: 4),
                              Text(
                                '(${product['reviewCount']})',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.visibility, color: Colors.green.shade400),
                            onPressed: () => _showProductReviews(product),
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most Reviewed Products',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      if (filteredProducts.where((p) => p['reviewCount'] > 0).isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No product reviews available',
                              style: GoogleFonts.poppins(color: Colors.black54),
                            ),
                          ),
                        )
                      else
                        ...filteredProducts
                            .where((p) => p['reviewCount'] > 0)
                            .toList()
                            .sortedBy<num>((p) => -p['reviewCount'])
                            .take(5)
                            .map((product) => ListTile(
                          leading: product['image'] != null &&
                              product['image'].isNotEmpty
                              ? Image.network(
                            product['image'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, size: 40),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                          )
                              : const Icon(Icons.image_not_supported, size: 40),
                          title: Text(
                            product['name'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Row(
                            children: [
                              ...List.generate(5, (index) => Icon(
                                index < product['averageRating']
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 14,
                              )),
                              const SizedBox(width: 4),
                              Text(
                                '(${product['reviewCount']})',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.visibility, color: Colors.green.shade400),
                            onPressed: () => _showProductReviews(product),
                          ),
                        ))
                            .toList(),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

extension ListExtension<T> on List<T> {
  List<T> sortedBy<R extends Comparable<R>>(R Function(T) keyOf) {
    final List<T> result = List.of(this);
    result.sort((a, b) => keyOf(a).compareTo(keyOf(b)));
    return result;
  }

  List<T> take(int count) {
    return sublist(0, count < length ? count : length);
  }
}