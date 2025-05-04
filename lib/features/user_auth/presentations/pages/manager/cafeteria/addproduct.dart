import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../../loginpage.dart';
import 'deleteproducts.dart'; // Assuming you'll create DeleteCafeteriaProductPage

class AddCafeteriaProduct extends StatefulWidget {
  @override
  _AddCafeteriaProductState createState() => _AddCafeteriaProductState();
}

class _AddCafeteriaProductState extends State<AddCafeteriaProduct> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  String _selectedCategory = 'Snacks';
  final List<String> _categories = ['Snacks', 'Meals', 'Beverages', 'Others'];
  bool _isTodaySpecial = false;

  // Added for image handling
  File? _imageFile;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                GestureDetector(
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.photo_library),
                        SizedBox(width: 10),
                        Text('Gallery'),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const Divider(),
                GestureDetector(
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt),
                        SizedBox(width: 10),
                        Text('Camera'),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _uploadImageToStorage() async {
    if (_imageFile == null) return null;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Try to sign in with manager credentials
      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: 'main@gmail.com',
          password: 'subinraj',
        );
        user = userCredential.user;
        print("Logged in as manager for image upload: ${user?.uid}, Email: ${user?.email}");
      } catch (loginError) {
        print('Manager login failed during image upload: $loginError');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to upload an image')),
        );
        return null;
      }
    }

    try {
      final fileName =
          '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final storageRef = FirebaseStorage.instance.ref().child('cafeteria_images/$fileName');
      await storageRef.putFile(_imageFile!);
      final imageUrl = await storageRef.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        // Check for current user
        User? user = FirebaseAuth.instance.currentUser;

        // If no user is logged in, try to log in with manager credentials
        if (user == null) {
          print('No user found in currentUser, attempting to login with manager account');
          try {
            // Login with hardcoded manager credentials
            UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: 'main@gmail.com',
              password: 'subinraj',
            );
            user = userCredential.user;
            print("Logged in as manager: ${user?.uid}, Email: ${user?.email}");
          } catch (loginError) {
            print('Manager login failed: $loginError');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Manager account login failed. Please check credentials.')),
            );

            // Navigate to login page if manager login fails
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
            setState(() {
              _isUploading = false;
            });
            return;
          }
        }

        print("Current user: ${user?.uid}, Email: ${user?.email}");
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user signed in. Redirecting to login...')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
          return;
        }

        String? imageUrl;
        if (_imageFile != null) {
          imageUrl = await _uploadImageToStorage();
          if (imageUrl == null) {
            setState(() {
              _isUploading = false;
            });
            return;
          }
        }

        // Generate a unique productId based on name and timestamp
        String productId = '${_nameController.text.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

        DocumentReference docRef = await FirebaseFirestore.instance.collection('cafeteriaproducts').add({
          'productId': productId,
          'name': _nameController.text,
          'price': double.parse(_priceController.text),
          'quantity': int.parse(_quantityController.text),
          'category': _selectedCategory,
          'status': 'Available',
          'image': imageUrl ?? 'assets/images/goal.png',
          'timestamp': FieldValue.serverTimestamp(),
          'isTodaySpecial': _isTodaySpecial,
          'userId': user.uid,
        });

        print('Cafeteria product added with ID: ${docRef.id}, productId: $productId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        print('Error adding cafeteria product: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _navigateToDeleteProductPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DeleteCafeteriaProductPage()), // Assuming this exists
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Cafeteria Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Added Image Picker Card
                    Card(
                      elevation: 4.0,
                      child: InkWell(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Add Product Image',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product Name field with Today's Special checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Product Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Please enter product name' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Today's Special checkbox with tooltip
                        Tooltip(
                          message: "Mark as Today's Special",
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isTodaySpecial = !_isTodaySpecial;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _isTodaySpecial ? Colors.green : Colors.grey,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: _isTodaySpecial ? Colors.green.withOpacity(0.1) : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: _isTodaySpecial ? Colors.amber : Colors.grey,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Today's\nSpecial",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _isTodaySpecial ? Colors.green : Colors.grey,
                                      fontWeight: _isTodaySpecial ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter price' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter quantity' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: _isUploading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isUploading
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Saving...'),
                    ],
                  )
                      : const Text('Save Product'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _navigateToDeleteProductPage,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Remove Product', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}