import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: screenHeight * 0.39,
                width: screenWidth * 0.823,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      // height: 320,
                      // width: 320,
                      height: screenHeight * 0.35,
                      width: screenWidth * 0.79,
                      left: screenWidth * 0.14,
                      top: screenHeight * 0.02,
                      child: Image.asset(
                        'assets/svg/cat-dog-balloon.png',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.032),
          
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: screenHeight * 0.11,
                    width: screenWidth * 1,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          height: screenHeight * 0.249,
                          width: screenWidth * 0.559,
                          left: -screenWidth * 0.132,
                          top: screenHeight * 0.033,
                          child: SvgPicture.asset(
                            'assets/svg/dawg.svg',
                          ),
                        ),
                        Positioned(
                          height: screenHeight * 0.107,
                          width: screenWidth * 0.25,
                          left: screenWidth * 0.799,
                          top: screenHeight * 0.08,
                          child: SvgPicture.asset(
                            'assets/svg/paw.svg',
                            // height: 80,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.13),
              
              // Login Button
              SizedBox(
                width: 340,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/login');
                  },
                  child: const Text('Login', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
          
              // Signup Button
              SizedBox(
                width: 340,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/signup');
                  },
                  child: const Text('Create New Account'),
                ),
              ),
          
              const SizedBox(height: 20),
          
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
                      left: 250,
                      top: 0,
                      child: Transform.rotate(
                        angle: -15 * 3.1416 / 180,
                        child: SvgPicture.asset(
                          'assets/svg/pawprint-centre.svg',
                          height: 90,
                          width: 15,
                          fit: BoxFit.contain,
                        ),
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
}