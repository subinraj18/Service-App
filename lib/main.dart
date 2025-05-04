import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/user_auth/presentations/pages/homepage.dart';
import 'features/user_auth/presentations/pages/loginpage.dart';
import 'features/user_auth/presentations/pages/manager/managerhome.dart';
import 'features/user_auth/presentations/pages/manager/managerstore.dart';
import 'features/user_auth/presentations/pages/manager/managercatten.dart';
import 'features/user_auth/presentations/pages/manager/managercafeteria.dart';
import 'features/user_auth/presentations/pages/prakash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String userType = prefs.getString('userType') ?? 'user';
  String? serviceType = prefs.getString('serviceType');

  runApp(MyApp(isLoggedIn: isLoggedIn, userType: userType, serviceType: serviceType));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userType;
  final String? serviceType;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.userType,
    this.serviceType,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? _getHomePage() : LoginPage(),
    );
  }

  Widget _getHomePage() {
    switch (serviceType ?? userType) {
      case 'store':
        return MStorePage();
      case 'canteen':
        return MCanteenPage();
      case 'cafeteria':
        return MCafeteriaPage();
      case 'manager':
        return ManagerHomePage();
      case 'prakash':
        return PrakashPage();
      case 'user':
      default:
        return const HomePage();
    }
  }
}
