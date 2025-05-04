import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../campusupdate.dart';
import 'cafeteria/addproduct.dart';
import 'cafeteria/cafeteriaanalysis.dart';
import 'cafeteria/cafeteriaorders.dart';
import 'campusupdate.dart';
import 'package:miniproject/features/user_auth/presentations/pages/loginpage.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for SharedPreferences

class MCafeteriaPage extends StatelessWidget {
  // Add logout method matching the canteen version
  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Reset login status
    await prefs.remove('serviceType'); // Clear service type

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Cafeteria Management",
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white, size: 30),
            onPressed: () {
              // Show logout dialog matching canteen version
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Logout'),
                  content: Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        _logout(context); // Call logout method instead of direct navigation
                      },
                      child: Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade300, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCategoryCard("Add Product", Icons.add_shopping_cart, Colors.green.shade400, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddCafeteriaProduct()),
                );
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Orders", Icons.shopping_bag, Colors.green.shade400, () {  // Changed icon to match canteen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CafeteriaOrdersPage()),
                );
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Analysis", Icons.analytics, Colors.green.shade400, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CafeteriaAnalysisPage()),
                );
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Updates", Icons.campaign, Colors.green.shade400, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CampusUpdatesPage()),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: color),
            SizedBox(width: 15),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}