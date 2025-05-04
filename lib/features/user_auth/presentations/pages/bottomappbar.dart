import 'package:flutter/material.dart';
import 'package:miniproject/features/user_auth/presentations/pages/settings.dart';
import 'package:miniproject/features/user_auth/presentations/pages/homepage.dart';

class BottomAppBarWidget extends StatelessWidget {
  const BottomAppBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ValueNotifier(true), // Set your logic to determine visibility
      builder: (context, isVisible, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isVisible ? 80.0 : 0.0, // Increased height
          child: Wrap(
            children: [
              BottomAppBar(
                color: Colors.white, // White background for bottom bar
                shape: const CircularNotchedRectangle(),
                notchMargin: 10.0, // Increased notch margin
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0), // Increased padding
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Home Icon
                      IconButton(
                        icon: const Icon(Icons.home, color: Colors.blue),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePage()),
                          );
                        },
                      ),

                      // Profile Icon
                      IconButton(
                        icon: const Icon(Icons.map, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const Placeholder()),
                          );
                        },
                      ),

                      // Notifications Icon
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const Placeholder()),
                          );
                        },
                      ),

                      // Settings Icon
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const Setting()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
