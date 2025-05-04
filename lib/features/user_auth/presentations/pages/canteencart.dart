import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class CanteenCartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CanteenCartPage({Key? key, required this.cartItems}) : super(key: key);

  @override
  _CanteenCartPageState createState() => _CanteenCartPageState();
}

class _CanteenCartPageState extends State<CanteenCartPage> {
  Map<String, dynamic> _userDetails = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _resolveImageUrls(); // Resolve Firebase Storage image URLs
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

  Future<void> _resolveImageUrls() async {
    for (var item in widget.cartItems) {
      if (!item['image'].toString().startsWith('http')) {
        try {
          final ref = FirebaseStorage.instance.ref().child(item['image']);
          final downloadUrl = await ref.getDownloadURL();
          item['image'] = downloadUrl;
        } catch (e) {
          print('Error loading image for ${item['name']}: $e');
        }
      }
    }
    setState(() {});
  }

  void _showRemoveDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Remove Item', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to remove this item from your cart?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.cartItems.removeAt(index);
                });
                Navigator.pop(context);
              },
              child: Text('Remove', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  double _calculateTotalPrice() {
    return widget.cartItems.fold(0, (total, item) => total + (item['price'] * item['quantity']));
  }

  Future<void> _confirmPurchase() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || _userDetails.isEmpty) {
        throw Exception('Please login to place an order');
      }

      String orderId = _userDetails['orderId'] ?? 'CSS6R2';

      for (var item in widget.cartItems) {
        DocumentSnapshot productDoc = await FirebaseFirestore.instance
            .collection('canteenproducts')
            .doc(item['id'])
            .get();

        if (!productDoc.exists) {
          throw Exception('${item['name']} is no longer available');
        }

        int availableQuantity = productDoc['quantity'] ?? 0;
        if (item['quantity'] > availableQuantity) {
          throw Exception('Not enough ${item['name']} available');
        }
      }

      Map<String, dynamic> order = {
        'userId': currentUser.uid,
        'userName': _userDetails['username'] ?? 'Unknown User',
        'userEmail': currentUser.email,
        'userDepartment': _userDetails['department'] ?? '',
        'userSemester': _userDetails['semester'] ?? '',
        'userRollNumber': _userDetails['rollNumber'] ?? '',
        'orderId': orderId,
        'products': widget.cartItems.map((item) => {
          'id': item['id'],
          'name': item['name'],
          'quantity': item['quantity'],
          'price': item['price'],
          'image': item['image'],
          'status': 'Processing'
        }).toList(),
        'totalPrice': _calculateTotalPrice(),
        'status': 'Processing',
        'timestamp': FieldValue.serverTimestamp(),
      };

      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference orderRef = FirebaseFirestore.instance.collection('canteenorders').doc();
      batch.set(orderRef, order);

      for (var item in widget.cartItems) {
        DocumentReference productRef = FirebaseFirestore.instance
            .collection('canteenproducts')
            .doc(item['id']);
        batch.update(productRef, {
          'quantity': FieldValue.increment(-item['quantity'])
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order placed! Order ID: $orderId'), backgroundColor: Colors.green),
      );

      setState(() {
        widget.cartItems.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Canteen Cart', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade500,
      ),
      body: widget.cartItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Your cart is empty', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.cartItems.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = widget.cartItems[index];
                final totalPrice = item['price'] * item['quantity'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            item['image'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 60),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 80,
                                height: 80,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'],
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('₹${item['price'].toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.red,
                                  onPressed: () {
                                    setState(() {
                                      if (item['quantity'] > 1) {
                                        item['quantity']--;
                                      } else {
                                        _showRemoveDialog(index);
                                      }
                                    });
                                  },
                                ),
                                Text('${item['quantity']}',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: Colors.green,
                                  onPressed: () {
                                    setState(() {
                                      item['quantity']++;
                                    });
                                  },
                                ),
                              ],
                            ),
                            Text('₹${totalPrice.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount:',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('₹${_calculateTotalPrice().toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Text('Place Order',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
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
