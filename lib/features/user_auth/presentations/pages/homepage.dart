import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miniproject/features/user_auth/presentations/pages/moreupdate.dart';
import 'package:miniproject/features/user_auth/presentations/pages/popular.dart';
import 'package:miniproject/features/user_auth/presentations/pages/recentorders.dart';
import 'package:miniproject/features/user_auth/presentations/pages/todayspecial.dart';
import 'package:miniproject/features/user_auth/presentations/pages/notification.dart';
import 'package:miniproject/features/user_auth/presentations/pages/search.dart';
import 'package:miniproject/features/user_auth/presentations/pages/settings.dart';
import 'package:miniproject/features/user_auth/presentations/pages/store.dart';
import 'orders.dart';
import 'canteen.dart';
import 'cafeteria.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isBottomAppBarVisible = ValueNotifier(true);
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? username;
  String? _imageUrl;
  bool _isRefreshing = false;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allUpdates = [];
  late Timer _updateTimer;
  final Random _random = Random();
  static const double _bottomAppBarHeight = 70.0;
  List<StreamSubscription<QuerySnapshot>> _orderSubscriptions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUsername();
    _loadProfileImage();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _scrollController.addListener(_onScroll);
    _isBottomAppBarVisible.addListener(() {
      setState(() {});
    });
    _fetchAllCampusUpdates();
    _startUpdateCycling();
    _listenToOrderUpdates();
    print("Current user: ${FirebaseAuth.instance.currentUser?.uid}");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfileData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && modalRoute.isCurrent) {
      _refreshProfileData();
    }
  }

  Future<void> _refreshProfileData() async {
    await _fetchUsername();
    await _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final ref = FirebaseStorage.instance.ref().child('users/${user.uid}/profile.jpg');
        final url = await ref.getDownloadURL();
        if (mounted) {
          setState(() {
            _imageUrl = url;
          });
        }
      } catch (e) {
        print("No profile image found or error: $e");
        if (mounted) {
          setState(() {
            _imageUrl = null;
          });
        }
      }
    }
  }

  Future<void> _fetchUsername() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            username = userDoc['username'] ?? "";
          });
        }
      } catch (e) {
        print("Error fetching username: $e");
      }
    }
  }

  Future<void> _fetchAllCampusUpdates() async {
    try {
      print('Fetching campus updates...');
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('campus_updates')
          .orderBy('timestamp', descending: true)
          .get();

      print('Retrieved ${querySnapshot.docs.length} updates');

      if (querySnapshot.docs.isEmpty) {
        print('No campus updates found in Firestore');
        setState(() {
          _allUpdates = [];
        });
        return;
      }

      if (mounted) {
        setState(() {
          _allUpdates = querySnapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            print('Processing update: ${data['title']}');
            Timestamp timestamp = data['timestamp'] as Timestamp;
            DateTime dateTime = timestamp.toDate();
            String timeAgo = _getTimeAgo(dateTime);

            return {
              'id': doc.id,
              'title': data['title'] ?? 'Update',
              'description': data['description'] ?? '',
              'timeAgo': timeAgo,
            };
          }).toList();
        });
      }

      print('Updates processed: ${_allUpdates.length}');
    } catch (e) {
      print('Error fetching campus updates: $e');
      if (mounted) {
        setState(() {
          _allUpdates = [];
        });
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else {
      return 'Just now';
    }
  }

  void _startUpdateCycling() {
    _updateTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_allUpdates.isNotEmpty && mounted) {
        setState(() {});
      }
    });
  }

  List<Map<String, dynamic>> _getCurrentUpdates() {
    if (_allUpdates.isEmpty) return [];

    Set<String> uniqueIds = {};
    List<Map<String, dynamic>> uniqueUpdates = [];

    List<Map<String, dynamic>> shuffledUpdates = List.from(_allUpdates);
    shuffledUpdates.shuffle(_random);

    for (var update in shuffledUpdates) {
      String id = update['id'];
      if (!uniqueIds.contains(id)) {
        uniqueIds.add(id);
        uniqueUpdates.add(update);
      }
      if (uniqueUpdates.length >= 3) break;
    }

    return uniqueUpdates;
  }

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    _animationController.reset();
    await _fetchUsername();
    await _loadProfileImage();
    await _fetchAllCampusUpdates();
    _animationController.forward();
    setState(() {
      _isRefreshing = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isBottomAppBarVisible.value) {
        _isBottomAppBarVisible.value = false;
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isBottomAppBarVisible.value) {
        _isBottomAppBarVisible.value = true;
      }
    }
  }

  void _listenToOrderUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user logged in, cannot listen to order updates.");
      return;
    }

    print("Listening to order updates for user: ${user.uid}");

    const collections = ['store_orders', 'canteen_orders', 'cafeteria_orders'];

    for (var collection in collections) {
      FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((orderSnapshot) async {
        print("Snapshot for $collection: ${orderSnapshot.docs.length} orders found");

        for (var orderDoc in orderSnapshot.docs) {
          final orderId = orderDoc.id;
          final productsStream = FirebaseFirestore.instance
              .collection(collection)
              .doc(orderId)
              .collection('products')
              .snapshots();

          final subscription = productsStream.listen((productSnapshot) {
            print("Products snapshot for $collection/$orderId: ${productSnapshot.docChanges.length} changes");
            for (var change in productSnapshot.docChanges) {
              final productData = change.doc.data() as Map<String, dynamic>?;
              final productId = change.doc.id;
              print("Product change in $collection/$orderId/products/$productId: Type: ${change.type}, Data: $productData");

              if (productData != null && productData['status'] == 'ready') {
                print("Product $productId in order $orderId from $collection is ready!");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Order #$orderId (Product: $productId) from ${collection.replaceAll('_orders', '').capitalize()} is ready!",
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'View',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductAlertsPage()));
                        },
                      ),
                    ),
                  );
                } else {
                  print("Widget not mounted, cannot show SnackBar");
                }
              } else {
                print("Product $productId status: ${productData?['status'] ?? 'No status'}");
              }
            }
          }, onError: (error) {
            print("Error in products subscription for $collection/$orderId: $error");
          });

          _orderSubscriptions.add(subscription);
        }
      }, onError: (error) {
        print("Error in $collection subscription: $error");
      });
    }
  }

  @override
  void dispose() {
    for (var subscription in _orderSubscriptions) {
      subscription.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _animationController.dispose();
    _isBottomAppBarVisible.dispose();
    _updateTimer.cancel();
    super.dispose();
  }

  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationSettingsPage()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => Setting())).then((_) {
          _refreshProfileData();
        });
        break;
    }
  }

  Widget _buildCategoryCard(String title, IconData icon, Widget page, Color gradientStart, Color gradientEnd) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientStart.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientStart, gradientEnd],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -10,
                top: -10,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFf8f9fa),
                Color(0xFFe9ecef),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        expandedHeight: 200,
                        floating: false,
                        pinned: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(30),
                                bottomRight: Radius.circular(30),
                              ),
                              image: DecorationImage(
                                image: AssetImage('assets/images/marian.jpg'), // Replace with your image path
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Hello,",
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                color: Colors.white.withOpacity(1),
                                              ),
                                            ),
                                            Text(
                                              username?.isNotEmpty == true
                                                  ? username![0].toUpperCase() + username!.substring(1).toLowerCase()
                                                  : "User",
                                              style: GoogleFonts.poppins(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Hero(
                                          tag: 'profileImage',
                                          child: Container(
                                            padding: EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 30,
                                              backgroundColor: Colors.white.withOpacity(0.2),
                                              backgroundImage: _imageUrl != null ? NetworkImage(_imageUrl!) : null,
                                              child: _imageUrl == null
                                                  ? Icon(
                                                Icons.person,
                                                size: 30,
                                                color: Colors.white,
                                              )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 52),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "What would you like today?",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  body: RefreshIndicator(
                    onRefresh: _refreshPage,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: _isBottomAppBarVisible.value
                            ? _bottomAppBarHeight + MediaQuery.of(context).padding.bottom + 16
                            : MediaQuery.of(context).padding.bottom + 16,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Text(
                                  "Categories",
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2b2d42),
                                  ),
                                ),
                              ),
                              GridView.count(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                childAspectRatio: 0.9,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                padding: EdgeInsets.zero,
                                children: [
                                  _buildCategoryCard(
                                    "Store",
                                    Icons.store,
                                    StorePage(),
                                    Color(0xFFff9e00),
                                    Color(0xFFff7b00),
                                  ),
                                  _buildCategoryCard(
                                    "Canteen",
                                    Icons.fastfood,
                                    CanteenPage(),
                                    Color(0xFF4cc9f0),
                                    Color(0xFF4361ee),
                                  ),
                                  _buildCategoryCard(
                                    "Cafeteria",
                                    Icons.restaurant_menu,
                                    CafeteriaPage(),
                                    Color(0xff07ca6c),
                                    Color(0xff12b15a),
                                  ),
                                  _buildCategoryCard(
                                    "Orders",
                                    Icons.receipt_long,
                                    ProductAlertsPage(),
                                    Color(0xff9512a8),
                                    Color(0xFFb5179e),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              Container(
                                margin: EdgeInsets.only(top: 16),
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Quick Access",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2b2d42),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildQuickAccessItem(
                                          Icons.fastfood,
                                          "Today's\nSpecial",
                                              () => Navigator.push(
                                              context, MaterialPageRoute(builder: (_) => TodaysSpecialPage())),
                                          Color(0xFFf72585),
                                        ),
                                        _buildQuickAccessItem(
                                          Icons.shopping_basket,
                                          "Popular\nItems",
                                              () => Navigator.push(
                                              context, MaterialPageRoute(builder: (_) => PopularItemsPage())),
                                          Color(0xFF4361ee),
                                        ),
                                        _buildQuickAccessItem(
                                          Icons.receipt,
                                          "Recent\nOrders",
                                              () => Navigator.push(
                                              context, MaterialPageRoute(builder: (_) => NewOrdersPage())),
                                          Color(0xFF06d6a0),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(top: 16),
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Campus Updates",
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2b2d42),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                                context, MaterialPageRoute(builder: (_) => Moreupdate()));
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Color(0xff2556f7).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward,
                                              color: Color(0xff1636d6),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    _allUpdates.isEmpty
                                        ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          "No updates available",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                        : Column(
                                      children: List.generate(
                                        _getCurrentUpdates().length,
                                            (index) {
                                          final update = _getCurrentUpdates()[index];
                                          return Column(
                                            children: [
                                              _buildUpdateItem(
                                                update['title'],
                                                update['description'],
                                                update['timeAgo'],
                                              ),
                                              if (index < _getCurrentUpdates().length - 1) Divider(),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isRefreshing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.1),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361ee)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _isBottomAppBarVisible,
          builder: (context, isVisible, child) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0, 1),
                    end: Offset(0, 0),
                  ).animate(animation),
                  child: child,
                );
              },
              child: isVisible
                  ? Container(
                key: ValueKey('bottomAppBar'),
                height: _bottomAppBarHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home, "Home", 0),
                    _buildNavItem(Icons.search, "Search", 1),
                    _buildNavItem(Icons.notifications, "Alerts", 2),
                    _buildNavItem(Icons.person, "Profile", 3),
                  ],
                ),
              )
                  : SizedBox.shrink(key: ValueKey('noBottomAppBar')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _navigateToPage(index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFe9f0ff) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Color(0xFF4361ee) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Color(0xFF4361ee) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessItem(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(String title, String description, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF4361ee).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications,
              color: Color(0xFF4361ee),
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  time,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class StreamGroup {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    for (var stream in streams) {
      stream.listen(controller.add, onError: controller.addError, onDone: () {});
    }
    return controller.stream;
  }
}