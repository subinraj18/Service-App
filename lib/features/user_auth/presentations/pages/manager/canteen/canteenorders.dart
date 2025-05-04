import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'ordertransaction.dart';

class CanteenOrdersPage extends StatefulWidget {
  const CanteenOrdersPage({Key? key}) : super(key: key);

  @override
  State<CanteenOrdersPage> createState() => _CanteenOrdersPageState();
}

class _CanteenOrdersPageState extends State<CanteenOrdersPage> {
  // Use a consistent collection name
  final String _collectionName = 'canteenorders';

  // Modified stream to exclude picked-up orders
  Stream<QuerySnapshot> get _ordersStream => FirebaseFirestore.instance
      .collection(_collectionName)
      .where('status', isNotEqualTo: 'pickedup')
      .orderBy('status')
      .orderBy('timestamp', descending: true)
      .snapshots();

  bool areAllProductsReady(List<Map<String, dynamic>> products) {
    return products.every((product) => product['status'] == 'Ready');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canteen Orders'), // Fixed capitalization
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.black),
            tooltip: 'View Order Transactions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CanteenOrderTransactionsPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No active orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var order = doc.data() as Map<String, dynamic>?; // Safely handle null
              if (order == null) {
                return const ListTile(
                  title: Text('Error: Invalid order data'),
                );
              }

              var orderId = doc.id;
              var orderIdField = order['orderId'] as String? ?? 'Unknown';
              var products = (order['products'] as List<dynamic>?)?.map((item) {
                if (item is Map) {
                  return Map<String, dynamic>.from(item);
                }
                return <String, dynamic>{};
              }).toList() ?? [];
              bool allProductsReady = areAllProductsReady(products);

              return Card(
                margin: const EdgeInsets.all(8),
                color: allProductsReady ? Colors.green.shade100 : null,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.green),
                          tooltip: 'Mark as Picked Up',
                          onPressed: () => _confirmPickupOrder(orderId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Order',
                          onPressed: () => _confirmDeleteOrder(orderId),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      title: Text(
                        'Order ID: $orderIdField',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${order['userName'] as String? ?? 'Unknown'}'),
                          Text(
                              'Department: ${order['userDepartment'] as String? ?? 'N/A'} - ${order['userSemester'] as String? ?? 'N/A'}'),
                          Text(
                            'Total: ₹${(order['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          Text(
                            'Time: ${(order['timestamp'] as Timestamp?) != null ? DateFormat('dd/MM/yyyy HH:mm').format(order['timestamp'].toDate()) : 'N/A'}',
                          ),
                        ],
                      ),
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          itemBuilder: (context, productIndex) {
                            var product = products[productIndex];
                            bool isReady = (product['status'] as String?) == 'Ready';
                            num quantity = (product['quantity'] as num?) ?? 0;

                            return ListTile(
                              leading: Image.network(
                                product['image'] as String? ?? '',
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
                              title: Text(product['name'] as String? ?? 'Unknown'),
                              subtitle: Text('Quantity: $quantity'),
                              tileColor: isReady ? Colors.green.shade100 : null,
                              trailing: Checkbox(
                                value: isReady,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    _updateProductStatus(
                                      orderId,
                                      productIndex,
                                      value ? 'Ready' : 'Pending',
                                      products,
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateProductStatus(
      String orderId,
      int productIndex,
      String newStatus,
      List<Map<String, dynamic>> products,
      ) async {
    try {
      products[productIndex]['status'] = newStatus;
      await FirebaseFirestore.instance
          .collection(_collectionName) // Use consistent collection name
          .doc(orderId)
          .update({'products': products});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product status updated to $newStatus')),
      );
      // No need for setState since StreamBuilder will rebuild automatically
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  // Confirm before marking as picked up
  void _confirmPickupOrder(String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Pickup'),
          content: const Text('Mark this order as picked up?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop();
                _updateOrderStatus(orderId, 'pickedup');
              },
            ),
          ],
        );
      },
    );
  }

  // Method to update order status
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Get the current order data
      DocumentSnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection(_collectionName) // Use consistent collection name
          .doc(orderId)
          .get();

      if (orderSnapshot.exists) {
        var orderData = orderSnapshot.data() as Map<String, dynamic>?;
        if (orderData == null) {
          throw Exception('Order data is null');
        }
        List<Map<String, dynamic>> products = (orderData['products'] as List<dynamic>?)?.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).toList() ?? [];

        // If status is being set to 'pickedup', update each product's status
        if (newStatus == 'pickedup') {
          for (int i = 0; i < products.length; i++) {
            products[i]['status'] = 'PickedUp';
          }

          // Update both the overall status and product statuses
          await FirebaseFirestore.instance
              .collection(_collectionName) // Use consistent collection name
              .doc(orderId)
              .update({
            'status': newStatus,
            'products': products,
          });
        } else {
          // Just update the overall status
          await FirebaseFirestore.instance
              .collection(_collectionName) // Use consistent collection name
              .doc(orderId)
              .update({'status': newStatus});
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as picked up')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order status: $e')),
      );
    }
  }

  // Method to show delete confirmation dialog
  void _confirmDeleteOrder(String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this order?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteOrder(orderId);
              },
            ),
          ],
        );
      },
    );
  }

  // Method to delete the order
  Future<void> _deleteOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collectionName) // Use consistent collection name
          .doc(orderId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting order: $e')),
      );
    }
  }
}