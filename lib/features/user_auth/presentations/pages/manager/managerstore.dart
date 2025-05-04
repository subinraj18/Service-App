import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miniproject/features/user_auth/presentations/pages/manager/store/orders.dart';
import 'package:miniproject/features/user_auth/presentations/pages/manager/store/storeanalysis.dart';
import 'package:miniproject/features/user_auth/presentations/pages/manager/campusupdate.dart';
import 'package:miniproject/features/user_auth/presentations/pages/manager/store/addproduct.dart';

import 'package:miniproject/features/user_auth/presentations/pages/loginpage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MStorePage extends StatefulWidget {
  @override
  _MStorePageState createState() => _MStorePageState();
}

class _MStorePageState extends State<MStorePage> {
  bool _isStoreOpen = false;
  bool _isSuddenClosure = false;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String storeTimeDocId = 'current_store_status';

  @override
  void initState() {
    super.initState();
    _loadStoreStatus();
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 60));
      if (mounted) _updateStatusBasedOnTime();
      return mounted;
    });
  }

  Future<void> _loadStoreStatus() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('storetime')
          .doc(storeTimeDocId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _isStoreOpen = data['isStoreOpen'] ?? false;
          _isSuddenClosure = data['isSuddenClosure'] ?? false;
          if (data['openTime'] != null) {
            _openTime = TimeOfDay(
              hour: data['openTime']['hour'],
              minute: data['openTime']['minute'],
            );
          }
          if (data['closeTime'] != null) {
            _closeTime = TimeOfDay(
              hour: data['closeTime']['hour'],
              minute: data['closeTime']['minute'],
            );
          }
        });
        _updateStatusBasedOnTime();
      }
    } catch (e) {
      print('Error loading store status: $e');
    }
  }

  Future<void> _saveStoreStatus() async {
    try {
      Map<String, dynamic> data = {
        'isStoreOpen': _isStoreOpen,
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
          .collection('storetime')
          .doc(storeTimeDocId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error saving store status: $e');
    }
  }

  void _updateStatusBasedOnTime() {
    if (_isSuddenClosure) return;

    final now = TimeOfDay.now();
    bool shouldBeOpen = false;

    if (_openTime != null && _closeTime != null) {
      int nowMinutes = now.hour * 60 + now.minute;
      int openMinutes = _openTime!.hour * 60 + _openTime!.minute;
      int closeMinutes = _closeTime!.hour * 60 + _closeTime!.minute;

      if (closeMinutes < openMinutes) {
        shouldBeOpen = nowMinutes >= openMinutes || nowMinutes < closeMinutes;
      } else {
        shouldBeOpen = nowMinutes >= openMinutes && nowMinutes < closeMinutes;
      }
    }

    if (shouldBeOpen != _isStoreOpen) {
      setState(() {
        _isStoreOpen = shouldBeOpen;
      });
      _saveStoreStatus();
    }
  }

  Future<void> _logout() async {
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
        title: Text('Store Hours'),
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
                _updateStatusBasedOnTime();
              });
              await _saveStoreStatus();
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
          "Store Management",
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
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade300, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              SizedBox(height: 100),
              _buildStoreStatusSwitch(),
              SizedBox(height: 30),
              _buildCategoryCard("Add Product", Icons.add_shopping_cart, Colors.orange.shade400, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddProduct()));
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Orders", Icons.shopping_bag, Colors.orange.shade400, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => StoreOrdersPage()));
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Analysis", Icons.analytics, Colors.orange.shade400, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => StoreAnalysisPage()));
              }),
              SizedBox(height: 20),
              _buildCategoryCard("Updates", Icons.campaign, Colors.orange.shade400, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CampusUpdatesPage()));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreStatusSwitch() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      margin: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isStoreOpen
              ? [Colors.green.shade300, Colors.green.shade100]
              : [Colors.red.shade300, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _isStoreOpen ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
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
                _isStoreOpen ? Icons.store : Icons.store_outlined,
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
                _isStoreOpen ? "OPEN" : "CLOSED",
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
                  value: _isStoreOpen,
                  onChanged: (value) async {
                    setState(() {
                      _isStoreOpen = value;
                      _isSuddenClosure = !value;
                    });
                    await _saveStoreStatus();
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