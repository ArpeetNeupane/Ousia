import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class SignupContinueScreen extends StatefulWidget {
  final String username;
  final String email;
  final String password;
  final String confirmPassword;

  const SignupContinueScreen({
    super.key,
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  @override
  State<SignupContinueScreen> createState() => _SignupContinueScreenState();
}

class _SignupContinueScreenState extends State<SignupContinueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _picker = ImagePicker();

  File? _selfieFile;
  File? _idCardFile;

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                    'We need a bit more info',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffB2A0A0)
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Just 3 more steps',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 103, 103, 103),
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                  
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Date of Birth',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dateController,
                    style: TextStyle(color: Colors.grey[900]),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your date of birth';
                      }
                      return null;
                    },
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
                        firstDate: DateTime(2013),
                        lastDate: DateTime(2030),
                      );
              
                      if (pickedDate != null) {
                        _dateController.text =
                            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'When were you born?',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color.fromARGB(255, 255, 255, 255),
              
                      suffixIcon: Icon(
                        Icons.calendar_month,
                        color: Colors.grey[600],
                      ),
              
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[300]!),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: const Color.fromARGB(255, 225, 16, 16)!),
                      ),
                      errorStyle: TextStyle(
                        color: Color.fromARGB(255, 225, 16, 16),
                        fontSize: 12,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
              
                  const SizedBox(height: 20),
                  // Selfie Upload Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selfie',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                      );
              
                      if (image != null) {
                        setState(() {
                          _selfieFile = File(image.path);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[600]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _selfieFile == null
                                    ? Text(
                                        'Smile!!',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      )
                                    : Text(
                                        'Great job. Selfie uploaded.',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 16,
                                        ),
                                      )
                              ),
                              Icon(
                                Icons.upload_file_sharp,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Identity Card Upload Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Identity card',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
              
                      if (image != null) {
                        setState(() {
                          _idCardFile = File(image.path);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[600]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _idCardFile == null
                                    ? Text(
                                        'Let\'s see your id card.',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 16,
                                        ),
                                      )
                                    : Text(
                                        'Great job. Image Uploaded.',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 16,
                                        ),
                                      )
                              ),
                              Icon(
                                Icons.upload_file_sharp,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 55),
                  
                  // Sign Up Button
                  SizedBox(
                    width: 150,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          if (_selfieFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please upload a selfie')),
                            );
                            return;
                          }
                          
                          if (_idCardFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please upload your ID card')),
                            );
                            return;
                          }
                          
                          final birthDate = _dateController.text;
                          final authService = AuthService();
                          
                          final result = await authService.signup(
                            username: widget.username,
                            email: widget.email,
                            password: widget.password, 
                            confirmPassword: widget.confirmPassword, 
                            birthDate: DateTime.parse(birthDate), 
                            selfieImage: _selfieFile!,
                            idCardImage: _idCardFile! //! means im sure the variable isn't null at this point of execution
                          );
                          
                          if (result['success']) {
                            // Navigate to feed or main screen
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/user-interest',
                              (route) => false,
                            );
                          } else {
                            final errorMessage = result['message'] ?? 'Registration failed';
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMessage)),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 80),
                  // Paw prints decoration at bottom
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
                          top: -70,
                          child: SvgPicture.asset(
                            'assets/svg/dawg-full.svg',
                            height: 230,
                            width: 45,
                            fit: BoxFit.contain,
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