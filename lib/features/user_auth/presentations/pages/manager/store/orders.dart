import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'ordertransaction.dart';

class StoreOrdersPage extends StatefulWidget {
  const StoreOrdersPage({Key? key}) : super(key: key);

  @override
  State<StoreOrdersPage> createState() => _StoreOrdersPageState();
}

class _StoreOrdersPageState extends State<StoreOrdersPage> {
  Stream<QuerySnapshot> get _ordersStream => FirebaseFirestore.instance
      .collection('storeorders')
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
        title: const Text('Store Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.black),
            tooltip: 'View Order Transactions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrderTransactionsPage()),
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
              var order = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var orderId = snapshot.data!.docs[index].id;
              var orderIdField = order['orderId'];
              var products = List<Map<String, dynamic>>.from(order['products'] ?? []);
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
                          Text('Customer: ${order['userName']}'),
                          Text('Department: ${order['userDepartment']} - ${order['userSemester']}'),
                          Text(
                            'Total: ₹${order['totalPrice']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          Text('Time: ${DateFormat('dd/MM/yyyy HH:mm').format(order['timestamp'].toDate())}'),
                        ],
                      ),
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          itemBuilder: (context, productIndex) {
                            var product = products[productIndex];
                            bool isReady = product['status'] == 'Ready';

                            return ListTile(
                              leading: product['image'] != null
                                  ? Image.network(
                                product['image'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                              )
                                  : const Icon(Icons.image_not_supported, size: 50),
                              title: Text(product['name']),
                              subtitle: Text('Quantity: ${product['quantity']}'),
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
          .collection('storeorders')
          .doc(orderId)
          .update({'products': products});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product status updated to $newStatus')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  void _confirmPickupOrder(String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Pickup'),
          content: const Text('Mark this order as picked up? It will be moved to Order Transactions.'),
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

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('storeorders')
          .doc(orderId)
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final products = List<Map<String, dynamic>>.from(orderData['products'] ?? []);

        for (var i = 0; i < products.length; i++) {
          products[i]['status'] = newStatus;
        }

        await FirebaseFirestore.instance
            .collection('storeorders')
            .doc(orderId)
            .update({
          'status': newStatus,
          'products': products,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as picked up and moved to Order Transactions')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order status: $e')),
      );
    }
  }

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

  Future<void> _deleteOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('storeorders')
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
