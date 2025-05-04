import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

class NewOrdersPage extends StatefulWidget {
  const NewOrdersPage({Key? key}) : super(key: key);

  @override
  _NewOrdersPageState createState() => _NewOrdersPageState();
}

class _NewOrdersPageState extends State<NewOrdersPage> {
  Stream<List<Map<String, dynamic>>> _getCombinedReadyOrdersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]); // Return empty stream if no user
    }

    // Stream for store orders
    final storeOrdersStream = FirebaseFirestore.instance
        .collection('storeorders')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        'category': 'store',
        'documentId': doc.id,
        'orderId': data['orderId'] ?? doc.id,
        'timestamp': data['timestamp'] ?? Timestamp.now(),
      };
    }).toList());

    // Stream for canteen orders
    final canteenOrdersStream = FirebaseFirestore.instance
        .collection('canteenorders')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        'category': 'canteen',
        'documentId': doc.id,
        'orderId': data['orderId'] ?? doc.id,
        'timestamp': data['timestamp'] ?? Timestamp.now(),
      };
    }).toList());

    // Combine streams and filter for "Ready" items
    return CombineLatestStream.list([storeOrdersStream, canteenOrdersStream])
        .map((List<List<Map<String, dynamic>>> streams) {
      final allOrders = [...streams[0], ...streams[1]];
      List<Map<String, dynamic>> readyItems = [];

      for (var order in allOrders) {
        final products = (order['products'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
            [];
        final readyProducts = products.where((product) {
          return product['status']?.toString().toLowerCase() == 'pickedup';
        }).toList();

        if (readyProducts.isNotEmpty) {
          readyItems.add({
            ...order,
            'products': readyProducts,
          });
        }
      }

      // Sort by timestamp descending
      readyItems.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp).toDate();
        final bTime = (b['timestamp'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });

      return readyItems;
    }).onErrorResume((error, stackTrace) {
      debugPrint('Stream error: $error');
      return Stream.value([]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recent Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getCombinedReadyOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No ready orders found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final timestamp = (order['timestamp'] as Timestamp).toDate();
    final products = List<Map<String, dynamic>>.from(order['products']);
    final totalPrice = products.fold<double>(
        0, (sum, item) => sum + (item['price'] as num) * (item['quantity'] as num));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order['orderId']}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy • HH:mm').format(timestamp),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order['category'] == 'store'
                        ? Colors.orange.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order['category'] == 'store' ? 'Store' : 'Canteen',
                    style: TextStyle(
                      color: order['category'] == 'store'
                          ? Colors.orange.shade900
                          : Colors.blue.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductItem(products[index]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    final imageUrl = product['image']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.grey,
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
            )
                : const SizedBox(
              width: 50,
              height: 50,
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name']?.toString() ?? 'Unnamed Item',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Qty: ${product['quantity']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '₹${(((product['price'] as num?) ?? 0) * ((product['quantity'] as num?) ?? 1)).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

}