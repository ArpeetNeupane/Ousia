import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SignupContinueScreen extends StatefulWidget {
  const SignupContinueScreen({super.key});

  @override
  State<SignupContinueScreen> createState() => _SignupContinueScreenState();
}

class _SignupContinueScreenState extends State<SignupContinueScreen> {
  final TextEditingController _dateController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2013),
                      lastDate: DateTime(2019),
                    );

                    if (pickedDate != null) {
                      _dateController.text =
                          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'When were you born?',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 255, 255, 255),

                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Icon(
                        Icons.calendar_month,
                        color: Colors.grey[600],
                      ),
                    ),

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
                // Selfie Upload Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selfie',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
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
                      border: Border.all(color: Colors.grey[300]!),
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
                                        color: Colors.grey[500],
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
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
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
                      border: Border.all(color: Colors.grey[300]!),
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
                    onPressed: () {
                      // Complete signup and navigate to main app
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/feed',
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 18,
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
    );
  }
}