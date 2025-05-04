import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;

  void _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults.clear();
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    List<Map<String, dynamic>> results = [];
    String normalizedQuery = query.toLowerCase(); // Normalize query to lowercase

    // Collections to search in
    List<String> collections = ['cafeteriaproducts', 'canteenproducts', 'storeproducts'];

    try {
      for (String collection in collections) {
        // Fetch all products and filter client-side for case-insensitive search
        QuerySnapshot snapshot = await FirebaseFirestore.instance.collection(collection).get();

        for (var doc in snapshot.docs) {
          Map<String, dynamic> product = doc.data() as Map<String, dynamic>;
          String productName = (product['name'] as String? ?? '').toLowerCase();

          // Check if the normalized product name contains the normalized query
          if (productName.contains(normalizedQuery)) {
            product['service'] = collection; // Store the service name
            results.add(product);
          }
        }
      }

      setState(() {
        searchResults = results;
        isLoading = false;
      });
    } catch (e) {
      print('Error searching: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Products'),
        backgroundColor: Colors.blue.shade400,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: _searchProducts,
              decoration: InputDecoration(
                labelText: 'Search for an item...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : searchResults.isEmpty
                ? Center(child: Text('No products found'))
                : ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return _buildProductCard(searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    String imageUrl = product['image'] as String? ?? ''; // Use 'image' field

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        contentPadding: EdgeInsets.all(10),
        title: Text(
          product['name'] ?? 'No Name',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 5),
            Text(
              product['description'] ?? 'No Description',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 5),
            Text(
              '₹${(product['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700]),
            ),
            SizedBox(height: 5),
            Text(
              'Service: ${product['service']}',
              style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.bold),
            ),
          ],
        ),
        leading: imageUrl.isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.broken_image,
                size: 40,
                color: Colors.grey,
              ),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 60,
                height: 60,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        (loadingProgress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                ),
              );
            },
          ),
        )
            : Container(
          width: 60,
          height: 60,
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.image_not_supported,
            size: 40,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}