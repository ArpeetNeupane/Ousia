import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class UserInterestScreen extends StatefulWidget {
  const UserInterestScreen({super.key});

  @override
  State<UserInterestScreen> createState() => _UserInterestScreenState();
}

class _UserInterestScreenState extends State<UserInterestScreen> {
  List<Map<String, dynamic>> _allInterests = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final _authService = AuthService();

  static const Map<String, IconData> _iconMap = {
    'drawing':     Icons.brush,
    'music':       Icons.music_note,
    'sports':      Icons.sports_soccer,
    'games':       Icons.games,
    'stories':     Icons.book,
    'science':     Icons.science,
    'nature':      Icons.nature,
    'cooking':     Icons.restaurant,
    'art':         Icons.palette,
    'reading':     Icons.menu_book,
    'technology':  Icons.computer,
    'travel':      Icons.flight,
    'fitness':     Icons.fitness_center,
    'photography': Icons.camera_alt,
    'movies':      Icons.movie,
    'coding':      Icons.code,
  };

  static IconData _iconFor(String name) =>
      _iconMap[name.toLowerCase()] ?? Icons.star_outline;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.fetchInterests();

    if (!mounted) return;

    if (result['success'] == true) {
      final List interests = result['interests'];
      setState(() {
        _allInterests = interests.map<Map<String, dynamic>>((item) {
          final name = item['name'] as String? ?? '';
          return {
            'id': item['id'],
            'name': name,
            'icon': _iconFor(name),
            'isSelected': false,
          };
        }).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSelectedInterests() async {
    final selectedIds = _allInterests
        .where((i) => i['isSelected'] == true)
        .map((i) => i['id'])
        .toList();

    // Validation: at least 3 interests
    if (selectedIds.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 interests.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // create a list of futures
    final futures = selectedIds.map((id) => _authService.saveUserInterests(id)).toList();

    // wait for all requests to complete in parallel
    final results = await Future.wait(futures);

    bool anyError = false;

    for (var result in results) {
      if (!result['success']) {
        anyError = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }

    setState(() => _isSaving = false);

    if (!anyError) {
      Navigator.pushNamedAndRemoveUntil(context, '/main-navigation-screen', (route) => false);
    }
  }

  List<Map<String, dynamic>> get _selectedInterests =>
      _allInterests.where((i) => i['isSelected'] as bool).toList();

  void _toggleInterest(int index) {
    setState(() {
      _allInterests[index]['isSelected'] =
          !(_allInterests[index]['isSelected'] as bool);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedInterests.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              const Text(
                'Interests',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffB2A0A0),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Pick any 3 you like to do.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 60),

              // Scrollable interest grid — expands to fill available space
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _loadInterests,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 3.0,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _allInterests.length,
                            itemBuilder: (context, index) {
                              final interest = _allInterests[index];
                              final isSelected =
                                  interest['isSelected'] as bool;

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
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        interest['icon'] as IconData,
                                        size: 20,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        interest['name'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: 180,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      (_isLoading || _isSaving) ? null : _saveSelectedInterests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC3B7F5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Confirm Interest${selectedCount != 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),

              const SizedBox(height: 16),

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