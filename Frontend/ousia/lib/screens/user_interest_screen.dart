import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserInterestScreen extends StatefulWidget {
  const UserInterestScreen({super.key});

  @override
  State<UserInterestScreen> createState() => _UserInterestScreenState();
}

class _UserInterestScreenState extends State<UserInterestScreen> {
  final List<Map<String, dynamic>> _allInterests = [
    {'name': 'Drawing', 'icon': Icons.brush, 'isSelected': false},
    {'name': 'Music', 'icon': Icons.music_note, 'isSelected': false},
    {'name': 'Sports', 'icon': Icons.sports_soccer, 'isSelected': false},
    {'name': 'Games', 'icon': Icons.games, 'isSelected': false},
    {'name': 'Stories', 'icon': Icons.book, 'isSelected': false},
    {'name': 'Science', 'icon': Icons.science, 'isSelected': false},
    {'name': 'Nature', 'icon': Icons.nature, 'isSelected': false},
    {'name': 'Cooking', 'icon': Icons.restaurant, 'isSelected': false},
  ];

  List<String> get _selectedInterests {
    return _allInterests
        .where((interest) => interest['isSelected'])
        .map<String>((interest) => interest['name'])
        .toList();
  }

  void _toggleInterest(int index) {
    setState(() {
      _allInterests[index]['isSelected'] = !_allInterests[index]['isSelected'];
    });
  }

  void _confirmInterests() {
    if (_selectedInterests.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 3 interests.'),
        ),
      );
      return;
    }

    // Navigate to the next screen or save interests
    print('Selected interests: $_selectedInterests');
    
    // Navigate to feed or next onboarding step
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/feed',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Title
              const Text(
                'Interests',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffB2A0A0),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'Pick any 3 you like to do.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 60),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Changed from 3 to 2 columns
                  childAspectRatio: 3.0, // Made boxes bigger
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _allInterests.length,
                itemBuilder: (context, index) {
                  final interest = _allInterests[index];
                  final isSelected = interest['isSelected'];
                  
                  return GestureDetector(
                    onTap: () => _toggleInterest(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFFC3B7F5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFFC3B7F5)
                              : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            interest['icon'],
                            size: 20, // Slightly bigger icon
                            color: isSelected 
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            interest['name'],
                            style: TextStyle(
                              fontSize: 15, // Bigger text
                              fontWeight: FontWeight.w500,
                              color: isSelected 
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                          // Removed the X icon completely
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40), // Moved button closer to options
              
              // Confirm button
              SizedBox(
                width: 180,
                height: 50,
                child: ElevatedButton(
                  onPressed: _confirmInterests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC3B7F5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Confirm Interest${_selectedInterests.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      // fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 150),

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
    );
  }
}