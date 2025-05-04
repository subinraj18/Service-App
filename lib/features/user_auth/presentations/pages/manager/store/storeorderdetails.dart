import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StoreProductDetailPage extends StatefulWidget {
  final List<dynamic> products;
  final String orderId;

  const StoreProductDetailPage({Key? key, required this.products, required this.orderId}) : super(key: key);

  @override
  State<StoreProductDetailPage> createState() => _StoreProductDetailPageState();
}

class _StoreProductDetailPageState extends State<StoreProductDetailPage> {
  late List<dynamic> localProducts;

  @override
  void initState() {
    super.initState();
    localProducts = List.from(widget.products);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Display orderId in the AppBar title
        title: Text(widget.orderId),
      ),
      body: Column(
        children: [
          Expanded(
            child: localProducts.isEmpty
                ? const Center(child: Text('No products in this order'))
                : ListView.builder(
              itemCount: localProducts.length,
              itemBuilder: (context, index) {
                final product = localProducts[index];
                return ListTile(
                  title: Text(product['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity: ${product['quantity']}'),
                      Text('Status: ${product['status'] ?? 'Pending'}')
                    ],
                  ),
                  trailing: DropdownButton<String>(
                    value: product['status'] ?? 'Pending',
                    items: ['Pending', 'Ready', 'Completed']
                        .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ))
                        .toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        _updateProductStatus(index, newStatus);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateProductStatus(int index, String newStatus) async {
    try {
      // Update local state
      setState(() {
        localProducts[index]['status'] = newStatus;
      });

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('storeorders')
          .doc(widget.orderId)
          .update({
        'products': localProducts,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product status updated to "$newStatus".')),
      );
    } catch (e) {
      print('Error updating product status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update product status: $e')),
      );
    }
  }
}