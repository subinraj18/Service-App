import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miniproject/features/user_auth/presentations/pages/manager/canteen/ordertransaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../campusupdate.dart';
import 'campusupdate.dart';
import 'canteen/add product.dart';
import 'package:miniproject/features/user_auth/presentations/pages/loginpage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:miniproject/features/user_auth/presentations/pages/manager/canteen/canteenanalysis.dart';
import 'package:miniproject/features/user_auth/presentations/pages/manager/canteen/canteenorders.dart';

class MCanteenPage extends StatefulWidget {
  @override
  _MCanteenPageState createState() => _MCanteenPageState();
}

class _MCanteenPageState extends State<MCanteenPage> {
  bool _isCanteenOpen = false;
  bool _isSuddenClosure = false;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String canteenTimeDocId = 'current_canteen_status';

  @override
  void initState() {
    super.initState();
    _loadCanteenStatus();
    // Periodically check time to update status
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 60)); // Check every minute
      if (mounted) _updateStatusBasedOnTime();
      return mounted; // Continue if still mounted
    });
  }

  Future<void> _loadCanteenStatus() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('canteentime')
          .doc(canteenTimeDocId)
          .get();

      if (doc.exists) {
        // Safely handle the data, no need for explicit cast
        final data = doc.data() as Map<String, dynamic>?; // Already typed as Map<String, dynamic>?
        if (data != null) {
          setState(() {
            _isCanteenOpen = data['isCanteenOpen'] as bool? ?? false;
            _isSuddenClosure = data['isSuddenClosure'] as bool? ?? false;
            if (data['openTime'] != null && data['openTime'] is Map) {
              final openTimeData = data['openTime'] as Map;
              _openTime = TimeOfDay(
                hour: openTimeData['hour'] as int? ?? 0,
                minute: openTimeData['minute'] as int? ?? 0,
              );
            }
            if (data['closeTime'] != null && data['closeTime'] is Map) {
              final closeTimeData = data['closeTime'] as Map;
              _closeTime = TimeOfDay(
                hour: closeTimeData['hour'] as int? ?? 0,
                minute: closeTimeData['minute'] as int? ?? 0,
              );
            }
          });
          _updateStatusBasedOnTime(); // Initial check
        } else {
          print('No data found in document');
        }
      } else {
        print('Document does not exist');
      }
    } catch (e) {
      print('Error loading canteen status: $e');
    }
  }

  Future<void> _saveCanteenStatus() async {
    try {
      Map<String, dynamic> data = {
        'isCanteenOpen': _isCanteenOpen,
        'isSuddenClosure': _isSuddenClosure,
        'openTime': _openTime != null
            ? {'hour': _openTime!.hour, 'minute': _openTime!.minute}
            : null,
        'closeTime': _closeTime != null
            ? {'hour': _closeTime!.hour, 'minute': _closeTime!.minute}
            : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('canteentime')
          .doc(canteenTimeDocId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error saving canteen status: $e');
    }
  }

  void _updateStatusBasedOnTime() {
    if (_isSuddenClosure) return; // Skip if manually closed

    final now = TimeOfDay.now();
    bool shouldBeOpen = false;

    if (_openTime != null && _closeTime != null) {
      int nowMinutes = now.hour * 60 + now.minute;
      int openMinutes = _openTime!.hour * 60 + _openTime!.minute;
      int closeMinutes = _closeTime!.hour * 60 + _closeTime!.minute;

      // Handle overnight schedules (e.g., 22:00 to 06:00)
      if (closeMinutes < openMinutes) {
        shouldBeOpen = nowMinutes >= openMinutes || nowMinutes < closeMinutes;
      } else {
        shouldBeOpen = nowMinutes >= openMinutes && nowMinutes < closeMinutes;
      }
    }

    if (shouldBeOpen != _isCanteenOpen) {
      setState(() {
        _isCanteenOpen = shouldBeOpen;
      });
      _saveCanteenStatus();
    }
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('Attempting to sign out...');
        await FirebaseAuth.instance.signOut();
        print('Sign out successful');

        // Clear all SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print('SharedPreferences cleared');

        if (!mounted) {
          print('Widget not mounted, aborting navigation');
          return;
        }

        // Clear the entire navigation stack and go to LoginPage
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
              (Route<dynamic> route) => false,
        );
        print('Navigation to LoginPage triggered');
      } catch (e) {
        print('Logout error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to logout: $e')),
          );
        }
      }
    } else {
      print('Logout canceled by user');
    }
  }
  void _showTimeScheduler(BuildContext context) {
    TimeOfDay? tempOpenTime = _openTime;
    TimeOfDay? tempCloseTime = _closeTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Canteen Hours'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Open Time: ${tempOpenTime?.format(context) ?? "Not set"}'),
                  trailing: Icon(Icons.edit),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: tempOpenTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() => tempOpenTime = time);
                    }
                  },
                ),
                ListTile(
                  title: Text('Close Time: ${tempCloseTime?.format(context) ?? "Not set"}'),
                  trailing: Icon(Icons.edit),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: tempCloseTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() => tempCloseTime = time);
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _openTime = tempOpenTime;
                _closeTime = tempCloseTime;
                _updateStatusBasedOnTime(); // Update status immediately
              });
              await _saveCanteenStatus();
              Navigator.pop(context);
            },
            child: Text('Set', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Canteen Management",
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
            icon: Icon(Icons.settings, color: Colors.white, size: 30),
            onPressed: () => _showTimeScheduler(context),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white, size: 30),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              SizedBox(height: 100), // Space below app bar
              _buildCanteenStatusSwitch(),
              SizedBox(height: 30),
              _buildCategoryCard("Add Product", Icons.add_shopping_cart, Colors.blue.shade400, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddCanteenProduct()),
                );
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Orders", Icons.shopping_bag, Colors.blue.shade400, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CanteenOrdersPage()),
                );
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Analysis", Icons.analytics, Colors.blue.shade400, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CanteenAnalysisPage()),
                );
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Updates", Icons.campaign, Colors.blue.shade400, () {
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

  Widget _buildCanteenStatusSwitch() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      margin: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isCanteenOpen
              ? [Colors.green.shade300, Colors.green.shade100]
              : [Colors.red.shade300, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _isCanteenOpen ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isCanteenOpen ? Icons.restaurant : Icons.restaurant_outlined,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                "Status",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                _isCanteenOpen ? "OPEN" : "CLOSED",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(width: 10),
              Transform.scale(
                scale: 1.2,
                child: Switch(
                  value: _isCanteenOpen,
                  onChanged: (value) async {
                    setState(() {
                      _isCanteenOpen = value;
                      _isSuddenClosure = !value; // Set sudden closure if manually closed
                    });
                    await _saveCanteenStatus();
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.green.shade700,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
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