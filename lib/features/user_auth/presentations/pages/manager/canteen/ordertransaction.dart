import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CanteenOrderTransactionsPage extends StatelessWidget {
  const CanteenOrderTransactionsPage({Key? key}) : super(key: key);

  Stream<QuerySnapshot> get _pastOrdersStream => FirebaseFirestore.instance
      .collection('canteenorders')
      .where('status', isEqualTo: 'pickedup')
      .orderBy('timestamp', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canteen Order Transactions'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _pastOrdersStream,
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
                'No past canteen orders found',
                style: TextStyle(fontSize: 18),
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

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(
                    'Order ID: $orderIdField',
                    style: const TextStyle(
                      fontSize: 20,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text('Time: ${DateFormat('dd/MM/yyyy HH:mm').format(order['timestamp'].toDate())}'),
                      Text(
                        'Status: Picked Up',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
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
                        );
                      },
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
}