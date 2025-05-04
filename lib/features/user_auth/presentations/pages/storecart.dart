import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CartPage({Key? key, required this.cartItems}) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Map<String, dynamic> _userDetails = {};

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(currentUser.uid)
            .get();

        setState(() {
          _userDetails = userDoc.data() as Map<String, dynamic>;
        });
      } catch (e) {
        print('Error fetching user details: $e');
      }
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await FirebaseFirestore.instance
        .collection('storeorders')
        .doc(orderId)
        .update({
      'status': status,
    });
  }

  void _showRemoveDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove item'),
          content:
          const Text('Are you sure you want to remove this item from the cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.cartItems.removeAt(index);
                });
                Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  double _calculateTotalPrice() {
    return widget.cartItems.fold(
      0,
          (total, item) => total + (item['price'] * item['quantity']),
    );
  }

  Future<void> _confirmPurchase() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || _userDetails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to place an order')),
        );
        return;
      }

      String orderId = _userDetails['orderId'] ?? 'CSS6R2';

      Map<String, dynamic> order = {
        'userId': currentUser.uid,
        'userName': _userDetails['username'] ?? 'Unknown User',
        'userEmail': currentUser.email,
        'userDepartment': _userDetails['department'] ?? '',
        'userSemester': _userDetails['semester'] ?? '',
        'userRollNumber': _userDetails['rollNumber'] ?? '',
        'orderId': orderId,
        'products': widget.cartItems.map((item) {
          return {
            'name': item['name'],
            'quantity': item['quantity'],
            'price': item['price'],
            'image': item['image'], // Firebase Storage URL
          };
        }).toList(),
        'totalPrice': _calculateTotalPrice(),
        'status': 'Processing',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('storeorders').add(order);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order placed! Order ID: $orderId')),
      );

      setState(() {
        widget.cartItems.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
      ),
      body: widget.cartItems.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) {
                final product = widget.cartItems[index];
                double totalPrice =
                    product['price'] * product['quantity'];

                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10.0),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product['image'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 50),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 50,
                            height: 50,
                            child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                    title: Text(
                      product['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              if (product['quantity'] > 1) {
                                product['quantity']--;
                              } else {
                                _showRemoveDialog(index);
                              }
                            });
                          },
                        ),
                        Text('${product['quantity']}'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              product['quantity']++;
                            });
                          },
                        ),
                      ],
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'x${product['quantity']}',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${_calculateTotalPrice().toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _confirmPurchase,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                    vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
                shadowColor: Colors.black.withOpacity(0.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Confirm Purchase',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
