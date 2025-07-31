import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthStage { login, signup }

class _AuthScreenState extends State<AuthScreen> {
  AuthStage _stage = AuthStage.login;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  bool _obscurePassword = true;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Check if user is already logged in
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null && mounted) {
      // User is already logged in, navigate to settings
      Navigator.pushNamedAndRemoveUntil(
        context, 
        '/settings', 
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> signup() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar("Please enter your email", Colors.orange);
      return;
    }
    
    if (!_isValidEmail(_emailController.text.trim())) {
      _showSnackBar("Please enter a valid email", Colors.orange);
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showSnackBar("Password must be at least 6 characters", Colors.orange);
      return;
    }
    
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Please enter your name", Colors.orange);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      print('Starting signup process...'); // Debug print
      
      // Create user with Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result.user != null) {
        // Save user profile to Firestore
        await _firestore.collection('users').doc(result.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Update display name
        await result.user!.updateDisplayName(_nameController.text.trim());
        
        print('Signup successful for: ${result.user!.email}'); // Debug print
        
        if (mounted) {
          _showSnackBar("Account created successfully! Welcome ${_nameController.text.trim()}!", Colors.green);
          
          // Small delay to show success message
          await Future.delayed(const Duration(seconds: 1));
          
          // Navigate to settings screen
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/settings', 
            (Route<dynamic> route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}'); // Debug print
      String errorMessage;
      
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        default:
          errorMessage = 'Signup failed: ${e.message}';
      }
      
      if (mounted) {
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      print('Signup error: $e'); // Debug print
      if (mounted) {
        _showSnackBar("Signup failed: Network error", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> login() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar("Please enter your email", Colors.orange);
      return;
    }
    
    if (!_isValidEmail(_emailController.text.trim())) {
      _showSnackBar("Please enter a valid email", Colors.orange);
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      _showSnackBar("Please enter your password", Colors.orange);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      print('Starting login process...'); // Debug print
      
      // Sign in with Firebase Auth
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result.user != null) {
        // Get user profile from Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .get();
        
        String userName = 'User';
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          userName = userData['name'] ?? result.user!.displayName ?? 'User';
        } else {
          // If user document doesn't exist, create it
          userName = result.user!.displayName ?? 'User';
          await _firestore.collection('users').doc(result.user!.uid).set({
            'name': userName,
            'email': result.user!.email,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        
        print('Login successful for: ${result.user!.email}'); // Debug print
        
        if (mounted) {
          _showSnackBar("Welcome back, $userName!", Colors.green);
          
          // Small delay to show success message
          await Future.delayed(const Duration(seconds: 1));
          
          // Navigate to settings screen
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/settings', 
            (Route<dynamic> route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}'); // Debug print
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      
      if (mounted) {
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      print('Login error: $e'); // Debug print
      if (mounted) {
        _showSnackBar("Login failed: Network error", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Password Reset Function
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar("Please enter your email to reset password", Colors.orange);
      return;
    }
    
    if (!_isValidEmail(_emailController.text.trim())) {
      _showSnackBar("Please enter a valid email", Colors.orange);
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showSnackBar("Password reset email sent! Check your inbox.", Colors.green);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for this email.';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }
      _showSnackBar(errorMessage, Colors.red);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: !_isLoading,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          suffixIcon: label == 'Password' ? IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.blue[700],
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(color: Colors.blue[700]),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget buildSignupForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock,
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 30),
              _buildGradientButton(
                text: "Sign Up",
                isLoading: _isLoading,
                onPressed: _isLoading ? null : signup,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading ? null : () {
                  _clearFields();
                  setState(() => _stage = AuthStage.login);
                },
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock,
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 15),
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildGradientButton(
                text: "Login",
                isLoading: _isLoading,
                onPressed: _isLoading ? null : login,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading ? null : () {
                  _clearFields();
                  setState(() => _stage = AuthStage.signup);
                },
                child: const Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _obscurePassword = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_stage) {
      case AuthStage.signup:
        content = buildSignupForm();
        break;
      case AuthStage.login:
        content = buildLoginForm();
        break;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[400]!,
              Colors.blue[600]!,
              Colors.blue[800]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 
                       MediaQuery.of(context).padding.top - 48,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      "Mock AI Interview",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: content,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}