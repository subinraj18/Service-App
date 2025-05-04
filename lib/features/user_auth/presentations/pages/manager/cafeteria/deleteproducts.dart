import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeleteCafeteriaProductPage extends StatefulWidget {
  @override
  _DeleteCafeteriaProductPageState createState() => _DeleteCafeteriaProductPageState();
}

class _DeleteCafeteriaProductPageState extends State<DeleteCafeteriaProductPage> {
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('cafeteriaproducts')
          .get();

      setState(() {
        products = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Product',
            'price': (data['price'] ?? 0.0).toDouble(),
            'image': data['image'] ?? 'https://via.placeholder.com/150', // Updated default to a network placeholder
            'quantity': data['quantity'] ?? 0,
            'category': data['category'] ?? 'Others',
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    try {
      await FirebaseFirestore.instance
          .collection('cafeteriaproducts')
          .doc(productId)
          .delete();

      setState(() {
        products.removeWhere((product) => product['id'] == productId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$productName deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product['id'], product['name']);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delete Cafeteria Products'),
        backgroundColor: Colors.red,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : products.isEmpty
          ? Center(child: Text('No products available'))
          : ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Image.network(
                product['image'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 50,
                    height: 50,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
              ),

              title: Text(product['name']),
              subtitle: Text(
                '₹${product['price']} - ${product['category']} - Qty: ${product['quantity']}',
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(product),
              ),
            ),
          );
        },
      ),
    );
  }
}