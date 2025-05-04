import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:miniproject/features/user_auth/presentations/pages/forgot.dart';
import 'package:miniproject/features/user_auth/presentations/pages/prakash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'homepage.dart';
import 'manager/managercafeteria.dart';
import 'manager/managercatten.dart';
import 'manager/managerhome.dart';
import 'manager/managerstore.dart';
import 'signuppage.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  final String? successMessage;

  LoginPage({super.key, this.successMessage});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String userType = prefs.getString('userType') ?? 'user';
    String? serviceType = prefs.getString('serviceType'); // Retrieve service type

    if (isLoggedIn) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null || serviceType != null) { // Check for service type as well
        try {
          if (user != null) {
            var userData = await FirebaseFirestore.instance
                .collection('students')
                .doc(user.uid)
                .get();
            if (!userData.exists) {
              await FirebaseAuth.instance.signOut();
              prefs.setBool('isLoggedIn', false);
              print("Account not found, logging out.");
              return;
            }
          }

          // Navigate based on serviceType or userType
          switch (serviceType ?? userType) {
            case 'store':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MStorePage()),
              );
              break;
            case 'canteen':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MCanteenPage()),
              );
              break;
            case 'cafeteria':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MCafeteriaPage()),
              );
              break;
            case 'manager':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ManagerHomePage()),
              );
              break;
            case 'prakash':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => PrakashPage()),
              );
              break;
            case 'user':
            default:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
          }
        } catch (e) {
          await FirebaseAuth.instance.signOut();
          prefs.setBool('isLoggedIn', false);
          print("Error during Firestore fetch: $e");
        }
      }
    }
  }

  Future<void> _signInWithEmailAndPassword(BuildContext context) async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog(context, "Email and Password cannot be empty.");
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check specific email-password combinations first
    if (email == "store@gmail.com" && password == "subinraj") {
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('serviceType', 'store'); // Store service type
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MStorePage()),
      );
      return;
    } else if (email == "canteen@gmail.com" && password == "subinraj") {
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('serviceType', 'canteen'); // Store service type
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MCanteenPage()),
      );
      return;
    } else if (email == "cafeteria@gmail.com" && password == "subinraj") {
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('serviceType', 'cafeteria'); // Store service type
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MCafeteriaPage()),
      );
      return;
    } else if (email == "main@gmail.com" && password == "subinraj") {
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userType', 'manager');
      await prefs.remove('serviceType'); // Clear serviceType for manager
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ManagerHomePage()),
      );
      return;
    }

    // Proceed with Firebase Authentication for other users
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      print("Login successful for UID: ${userCredential.user?.uid}");

      await prefs.setBool('isLoggedIn', true);

      String userType = 'user'; // Default for all users
      if (email == "prakash@gmail.com") {
        userType = 'prakash';
      }

      await prefs.setString('userType', userType);
      await prefs.remove('serviceType'); // Clear serviceType for non-service users

      switch (userType) {
        case 'prakash':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PrakashPage()),
          );
          break;
        case 'user':
        default:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
      }
    } on FirebaseAuthException catch (e) {
      print("Login Error: ${e.code} - ${e.message}");

      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No user found with this email.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password.";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email format.";
          break;
        case 'network-request-failed':
          errorMessage = "No internet connection.";
          break;
        case 'user-disabled':
          errorMessage = "Your account has been disabled. Contact support.";
          break;
        default:
          errorMessage = "Login failed: ${e.message}";
      }

      _showErrorDialog(context, errorMessage);
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error", style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.successMessage!),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: Image.asset(
                'assets/images/login.png',
                height: 250,
                width: 250,
              ),
            ),
            Text(
              'Welcome Back!',
              style: GoogleFonts.pacifico(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Login to continue',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                prefixIcon: const Icon(Icons.email, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _signInWithEmailAndPassword(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
                shadowColor: Colors.blue.withOpacity(0.3),
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ForgotPasswordPage(),
                  ),
                );
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(height: 0),
            Row(
              children: [
                const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5.0),
                  child: Text('OR', style: TextStyle(color: Colors.grey)),
                ),
                const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Don\'t have an account? ', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}