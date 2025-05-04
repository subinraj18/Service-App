import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cafeteriaordertransaction.dart';

class CafeteriaOrdersPage extends StatefulWidget {
  const CafeteriaOrdersPage({Key? key}) : super(key: key);

  @override
  State<CafeteriaOrdersPage> createState() => _CafeteriaOrdersPageState();
}

class _CafeteriaOrdersPageState extends State<CafeteriaOrdersPage> {
  // Modified stream to exclude picked-up orders
  Stream<QuerySnapshot> get _ordersStream => FirebaseFirestore.instance
      .collection('cafeteriaorders') // Changed from 'canteenorders'
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
        title: const Text('Cafeteria Orders'), // Changed from 'Canteen Orders'
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.black),
            tooltip: 'View Order Transactions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CafeteriaOrderTransactionsPage()),
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
          .collection('cafeteriaorders') // Changed from 'canteenorders'
          .doc(orderId)
          .update({'products': products});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product status updated to $newStatus')),
      );
      setState(() {}); // Trigger UI update
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
          .collection('cafeteriaorders') // Changed from 'canteenorders'
          .doc(orderId)
          .get();

      if (orderSnapshot.exists) {
        Map<String, dynamic> orderData = orderSnapshot.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(orderData['products'] ?? []);

        // If status is being set to 'pickedup', update each product's status
        if (newStatus == 'pickedup') {
          for (int i = 0; i < products.length; i++) {
            products[i]['status'] = 'PickedUp';
          }

          // Update both the overall status and product statuses
          await FirebaseFirestore.instance
              .collection('cafeteriaorders') // Changed from 'canteenorders'
              .doc(orderId)
              .update({
            'status': newStatus,
            'products': products,
          });
        } else {
          // Just update the overall status
          await FirebaseFirestore.instance
              .collection('cafeteriaorders') // Changed from 'canteenorders'
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
          .collection('cafeteriaorders') // Changed from 'canteenorders'
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