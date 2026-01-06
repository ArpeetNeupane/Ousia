import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/signup_continue_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Title
                  const Text(
                    'Join Ousia Today',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffB2A0A0)
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create an Account',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 103, 103, 103),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Username Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Username',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    validator: (value) {
                      final username = value?.trim();
                      if (username == null || username.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (username.length < 3 && username.length > 20) {
                        return 'Username must be between 3-20 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
                        return 'Only letters, numbers and underscore allowed';
                      }
                      return null;
                    },
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your desired username.',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: const Color.fromARGB(255, 255, 255, 255),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Parental Email Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Parental Email',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    validator: (value) {
                      final email = value?.trim();
                      if (email == null || email.isEmpty) {
                        return 'Please enter an email.';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                        return 'Invalid email format.';
                      }
                      return null;
                    },
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your parent\'s email.',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: const Color.fromARGB(255, 255, 255, 255),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Password Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      final password = value?.trim();
                      if (password == null || password.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (password.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'What\'s your secret code?',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: const Color.fromARGB(255, 255, 255, 255),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Confirm Password Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    validator: (value) {
                      final cPassword = value?.trim();
                      if (cPassword == null || cPassword.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (cPassword != _passwordController.text.trim()) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                      hintText: 'What\'s your secret code again?',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: const Color.fromARGB(255, 255, 255, 255),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[200]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Continue Button
                  SizedBox(
                    width: 150,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to the continue signup screen (selfie/ID upload)
                        if (_formKey.currentState!.validate()) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignupContinueScreen(
                                username: _usernameController.text.trim(),
                                email: _emailController.text.trim(),
                                password: _passwordController.text.trim(),
                                confirmPassword: _confirmPasswordController.text.trim(),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          // fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Divider with "or"
                  const Text(
                    'or',
                    style: TextStyle(
                      color: Color.fromARGB(255, 103, 103, 103),
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: Color.fromARGB(255, 103, 103, 103),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: Color.fromARGB(255, 179, 165, 236),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            // decoration: TextDecoration.underline
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 50),
                  
                  SizedBox(
                    height: 100,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -40,
                          top: 0,
                          child: Transform.rotate(
                            angle: 30 * 3.1416 / 180,
                            child: SvgPicture.asset(
                              'assets/svg/pawprint-centre.svg',
                              height: 90,
                              width: 15,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 100,
                          top: 0,
                          child: SvgPicture.asset(
                            'assets/svg/pawprint-centre.svg',
                            height: 90,
                            width: 15,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          left: 240,
                          top: -65,
                          child: SvgPicture.asset(
                            'assets/svg/dawg-full.svg',
                            height: 230,
                            width: 45,
                            fit: BoxFit.cover,
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
    );
  }
}