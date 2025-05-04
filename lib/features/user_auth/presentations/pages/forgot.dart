import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool isEmailSent = false;
  bool isLoading = false;

  // Function to send the verification email (Password Reset Email)
  Future<void> _sendVerificationCode(BuildContext context) async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showErrorDialog(context, "Please enter your email.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        isEmailSent = true;
        isLoading = false;
      });

      // Show success dialog after sending the verification email
      _showSuccessDialog(context, "A verification code has been sent to your email.");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog(context, "Failed to send verification email. Please try again.");
    }
  }

  // Function to change password after email verification
  Future<void> _changePassword(BuildContext context) async {
    String newPassword = _newPasswordController.text.trim();

    if (newPassword.isEmpty) {
      _showErrorDialog(context, "Please enter a new password.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        // If email is verified, update the password
        await user.updatePassword(newPassword);
        setState(() {
          isLoading = false;
        });
        // Show success dialog
        _showSuccessDialog(context, "Password has been successfully updated.");
      } else {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog(context, "Please verify your email before changing the password.");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog(context, "Failed to change the password. Please try again.");
    }
  }

  // Show an error dialog
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("Error", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  // Show a success dialog
  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text("Success", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Main content
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Decorative top elements
                      Hero(
                        tag: 'forgotPasswordIcon',
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.1),
                          ),
                          child: Icon(
                            Icons.lock_reset,
                            size: 60,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        "Forgot Password?",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        "Enter your email and we'll send you a link to reset your password",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Email input field with beautified design
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _emailController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                            labelText: 'Email Address',
                            labelStyle: TextStyle(color: primaryColor),
                            prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Beautiful button with gradients and animation effects
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () => _sendVerificationCode(context),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: primaryColor,
                            elevation: 5,
                            shadowColor: primaryColor.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Send Reset Link',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.send_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Back to login button
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Remember your password? Back to Login",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}