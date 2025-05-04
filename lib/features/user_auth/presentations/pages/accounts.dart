import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miniproject/features/user_auth/presentations/pages/update.dart';
import 'package:flutter/services.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> with SingleTickerProviderStateMixin {
  String username = '';
  String email = '';
  String phone = '';
  String orderId = '';
  String rollNumber = '';
  String semester = '';
  String department = '';
  String etlabName = '';
  String? _imageUrl; // Changed to store URL instead of base64 string
  bool isLoading = true;
  bool isChecked = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Fetch user data from Firestore
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      print("Fetching data for userId: $userId");

      try {
        DocumentSnapshot userData = await FirebaseFirestore.instance
            .collection('students')
            .doc(userId)
            .get();

        if (userData.exists) {
          print("User Data: ${userData.data()}");
          setState(() {
            username = userData['username'] ?? 'No Name';
            email = userData['email'] ?? 'No Email';
            phone = userData['phone'] ?? 'No Phone Number';
            orderId = userData['orderId'] ?? 'No Order ID';
            rollNumber = userData['rollNumber'] ?? 'No Roll Number';
            semester = userData['semester'] ?? 'No Semester';
            department = userData['department'] ?? 'No Department';
            etlabName = userData['etlabName'] ?? 'No Etlab Name';
            isLoading = false;
          });
        } else {
          print("No user data found");
          setState(() => isLoading = false);
        }
      } catch (e) {
        print("Error fetching user data: $e");
        setState(() => isLoading = false);
      }
    }
  }

  // Load profile image from Firebase Storage
  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final ref = FirebaseStorage.instance.ref().child('users/${user.uid}/profile.jpg');
        final url = await ref.getDownloadURL();
        setState(() {
          _imageUrl = url;
        });
      } catch (e) {
        print("No profile image found or error: $e");
        setState(() {
          _imageUrl = null;
        });
      }
    }
  }

  // Pick and upload image to Firebase Storage
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Show loading indicator
          setState(() => isLoading = true);

          // Create reference to Firebase Storage
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('users/${user.uid}/profile.jpg');

          // Upload file
          final bytes = await pickedFile.readAsBytes();
          await storageRef.putData(bytes);

          // Get download URL
          final downloadUrl = await storageRef.getDownloadURL();

          setState(() {
            _imageUrl = downloadUrl;
            isLoading = false;
          });
        }
      } catch (e) {
        print("Error uploading image: $e");
        setState(() => isLoading = false);
      }
    } else {
      print("No image selected.");
    }
  }

  // Delete account
  Future<void> _deleteAccount() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text("Deleting account..."),
              ],
            ),
          );
        },
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;

        // Delete user data from Firestore
        await FirebaseFirestore.instance
            .collection('students')
            .doc(userId)
            .delete();

        // Delete profile image from Firebase Storage
        try {
          await FirebaseStorage.instance
              .ref()
              .child('users/$userId/profile.jpg')
              .delete();
        } catch (e) {
          print("No profile image to delete or error: $e");
        }

        // Delete user from Firebase Authentication
        await user.delete();

        Navigator.of(context).pop();
        SystemNavigator.pop();
      }
    } catch (e) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Error"),
            content: Text("Failed to delete account: ${e.toString()}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    setState(() {
      isChecked = false;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Delete Account"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Are you sure you want to delete your account?"),
                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            isChecked = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          "I confirm the deletion of my account",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: isChecked
                      ? () async {
                    Navigator.of(context).pop();
                    await _deleteAccount();
                  }
                      : null,
                  child: Text(
                    "Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              _loadUserData();
              _loadProfileImage();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Account Details",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Manage your profile information",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade100,
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: _imageUrl != null
                                ? NetworkImage(_imageUrl!)
                                : null,
                            child: _imageUrl == null
                                ? Icon(Icons.person, size: 60, color: Colors.blue.shade400)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildDetailCard(
                      "Personal Information",
                      [
                        {"Username": username},
                        {"Email": email},
                        {"Phone": phone},
                      ],
                      Icons.person,
                      Colors.blue.shade400,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailCard(
                      "Academic Information",
                      [
                        {"Roll Number": rollNumber},
                        {"Semester": semester},
                        {"Department": department},
                        {"Etlab Name": etlabName},
                      ],
                      Icons.school,
                      Colors.orange.shade400,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailCard(
                      "Order Information",
                      [
                        {"Order ID": orderId},
                      ],
                      Icons.shopping_bag,
                      Colors.green.shade400,
                    ),
                    SizedBox(height: 30),
                    _buildActionButton(
                      "Update Details",
                      Icons.edit,
                      Colors.blue,
                          () {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UpdatePage(userId: user.uid),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You must be logged in to update details')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      "Delete Account",
                      Icons.delete_forever,
                      Colors.red,
                      _showDeleteConfirmationDialog,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Rest of the widget building methods remain the same
  Widget _buildDetailCard(String title, List<Map<String, String>> details, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...details.map((detail) => _buildDetailRow(detail.keys.first, detail.values.first)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}