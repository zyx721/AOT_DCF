import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:firebase_messaging/firebase_messaging.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false; // Declare loading state

  /// Function to generate and retrieve the device token for push notifications.
  Future<String?> generateDeviceToken() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request permission for notifications (only needed for iOS and macOS)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permissions denied');
        return null;
      }

      // Get the device token
      final String? token = await messaging.getToken();

      if (token != null) {
        debugPrint('Device token generated: $token');
        return token;
      } else {
        debugPrint('Failed to generate device token');
        return null;
      }
    } catch (e) {
      debugPrint('Error generating device token: $e');
      return null;
    }
  }

  Future<void> saveDeviceTokenToFirestore(String userId) async {
    try {
      final String? token = await generateDeviceToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'deviceToken': token,
        });
        debugPrint('Device token saved to Firestore: $token');
      } else {
        debugPrint('Device token generation failed');
      }
    } catch (e) {
      debugPrint('Error saving device token to Firestore: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose(); // Dispose controllers to free resources
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoading = false; // Loading state variable

  Widget _buildGoogleSignInButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        elevation: 6,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/google_logo.png',
                  height: 24,
                  width: 24,
                ),
                Text(
                  'Sign in with Google',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: const Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        try {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          final User? user = userCredential.user;

          if (user != null) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            Map<String, dynamic> userData = {
              'uid': user.uid,
              'email': user.email ?? 'No Email',
              'lastSignIn': DateTime.now(),
              'isConnected': true,
            };

            if (!userDoc.exists || userDoc.data()?['name'] == null) {
              userData['name'] = user.displayName ?? 'No Name';
            }

            if (!userDoc.exists ||
                userDoc.data()?['photoURL'] == null ||
                (userDoc.data()?['photoURL']?.isEmpty ?? true && user.photoURL != null && user.photoURL!.isNotEmpty)) {
              userData['photoURL'] = user.photoURL ?? '';
            }

            if (!userDoc.exists) {
              userData['createdAt'] = DateTime.now();
            }

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set(userData, SetOptions(merge: true));

            await saveDeviceTokenToFirestore(user.uid);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Welcome ${user.displayName ?? user.email}'),
                backgroundColor: Colors.green,
              ),
            );

            // Check if user has a country
            if (!userDoc.exists || !userDoc.data()!.containsKey('country')) {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/select-country');
              }
            } else {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/navbar');
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign-In failed. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'account-exists-with-different-credential') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account exists with different credentials.'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Authentication error: ${e.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In was canceled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during sign-in: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 106, 27, 154), // Rich Amethyst
              Color.fromARGB(255, 171, 71, 188), // Orchid
              Color.fromARGB(255, 145, 41, 140), // Wild Strawberry
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Wrap the logo with GestureDetector to detect taps
                  GestureDetector(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 8),
                                blurRadius: 200,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/onboarding3_b.png', // Replace with your logo path
                            height: 220,
                            width: 220,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField('Email', false, _emailController),
                  const SizedBox(height: 15),
                  _buildTextField('Password', true, _passwordController),
                  const SizedBox(height: 30),
                  _buildLoginButton(context, 'Login'),
                  const SizedBox(height: 20),
                  _buildGoogleSignInButton(),
                  _buildForgotPasswordButton(context, 'Forgot Password?'),
                  _buildSignupPrompt(context, 'Create New Account'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, bool obscureText, TextEditingController controller) {
    return TextField(
      controller: controller, // Bind the controller here
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      ),
      style: GoogleFonts.poppins(color: Colors.white),
    );
  }

  Widget _buildLoginButton(BuildContext context, String buttonText) {
    return ElevatedButton(
      onPressed: isLoading ? null : () => handleLogin(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: isLoading ? Colors.grey : const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        elevation: 6,
      ),
      child: isLoading
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
            )
          : Text(
              buttonText,
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: const Color(0xFF1A237E),
              ),
            ),
    );
  }

  Future<void> handleLogin(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Validate email format using a simple regex pattern
      final emailPattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$";
      final emailRegex = RegExp(emailPattern);

      if (email.isNotEmpty && password.isNotEmpty) {
        if (!emailRegex.hasMatch(email)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email format'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final UserCredential userCredential =
            await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final User? user = userCredential.user;

        if (user != null) {
          // Check if email is verified
          if (!user.emailVerified) {
            // Show verification needed message with resend option
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please verify your email before logging in'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Resend',
                  textColor: Colors.white,
                  onPressed: () async {
                    try {
                      await user.sendEmailVerification();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email sent'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error sending verification email'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            );

            // Sign out the user since they haven't verified their email
            await _auth.signOut();
            setState(() {
              isLoading = false;
            });
            return;
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'lastSignIn': DateTime.now(),
            'isConnected': true,
            'isEmailVerified': true,
          }, SetOptions(merge: true));

          await saveDeviceTokenToFirestore(user.uid);

          // Navigate based on user status
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (!userDoc.exists || !userDoc.data()!.containsKey('country')) {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/select-country');
            }
          } else {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/navbar');
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No user found for that email.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both email and password'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (error) {
      handleFirebaseAuthError(context, error);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

// Updated error handler to include verification-related errors
  void handleFirebaseAuthError(BuildContext context, Object error) {
    if (error is FirebaseAuthException) {
      String errorMessage;
      switch (error.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildForgotPasswordButton(
      BuildContext context, String forgotPasswordText) {
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, '/forgot-password');
      },
      child: Text(
        forgotPasswordText,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildSignupPrompt(BuildContext context, String signupPromptText) {
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, '/signup');
      },
      child: Text(
        signupPromptText,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.white70,
        ),
      ),
    );
  }
}
