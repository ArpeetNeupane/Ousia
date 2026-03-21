import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Data

class QuizCategory {
  final String title;
  final String duration;
  final String ageRange;
  final String imagePath;
  final List<QuizQuestion> questions;

  const QuizCategory({
    required this.title,
    required this.duration,
    required this.ageRange,
    required this.imagePath,
    required this.questions,
  });
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

final List<QuizCategory> quizCategories = [
  QuizCategory(
    title: 'Math Quiz',
    duration: '5 min',
    ageRange: '7–10',
    imagePath: 'assets/quiz/math.jpeg',
    questions: [
      QuizQuestion(question: 'What is 6 × 7?', options: ['40', '42', '48', '36'], correctIndex: 1),
      QuizQuestion(question: 'What is 15 ÷ 3?', options: ['3', '4', '5', '6'], correctIndex: 2),
      QuizQuestion(question: 'What is 23 + 48?', options: ['61', '71', '81', '51'], correctIndex: 1),
      QuizQuestion(question: 'What is 100 - 37?', options: ['63', '73', '53', '67'], correctIndex: 0),
      QuizQuestion(question: 'What is 8 × 9?', options: ['64', '81', '72', '56'], correctIndex: 2),
      QuizQuestion(question: 'What is 144 ÷ 12?', options: ['10', '11', '12', '13'], correctIndex: 2),
      QuizQuestion(question: 'What is 56 + 37?', options: ['83', '93', '73', '89'], correctIndex: 1),
      QuizQuestion(question: 'What is 200 - 85?', options: ['105', '115', '125', '135'], correctIndex: 1),
      QuizQuestion(question: 'What is 7 × 8?', options: ['54', '56', '63', '49'], correctIndex: 1),
      QuizQuestion(question: 'What is 81 ÷ 9?', options: ['7', '8', '9', '10'], correctIndex: 2),
    ],
  ),
  QuizCategory(
    title: 'Science Quiz',
    duration: '5 min',
    ageRange: '9–11',
    imagePath: 'assets/quiz/science.jpeg',
    questions: [
      QuizQuestion(question: 'What planet is closest to the Sun?', options: ['Venus', 'Earth', 'Mercury', 'Mars'], correctIndex: 2),
      QuizQuestion(question: 'What gas do plants absorb?', options: ['Oxygen', 'Carbon Dioxide', 'Nitrogen', 'Hydrogen'], correctIndex: 1),
      QuizQuestion(question: 'How many bones are in the human body?', options: ['196', '206', '216', '226'], correctIndex: 1),
      QuizQuestion(question: 'What is the powerhouse of the cell?', options: ['Nucleus', 'Ribosome', 'Mitochondria', 'Vacuole'], correctIndex: 2),
      QuizQuestion(question: 'What is H2O?', options: ['Salt', 'Sugar', 'Water', 'Acid'], correctIndex: 2),
      QuizQuestion(question: 'Which animal lays the largest eggs?', options: ['Ostrich', 'Elephant', 'Whale', 'Crocodile'], correctIndex: 0),
      QuizQuestion(question: 'What force keeps us on Earth?', options: ['Magnetism', 'Gravity', 'Friction', 'Tension'], correctIndex: 1),
      QuizQuestion(question: 'How many chambers does the heart have?', options: ['2', '3', '4', '5'], correctIndex: 2),
      QuizQuestion(question: 'What is the speed of light?', options: ['300,000 km/s', '150,000 km/s', '450,000 km/s', '100,000 km/s'], correctIndex: 0),
      QuizQuestion(question: 'Which planet has rings?', options: ['Jupiter', 'Mars', 'Saturn', 'Neptune'], correctIndex: 2),
    ],
  ),
  QuizCategory(
    title: 'Mystery Quiz',
    duration: '5 min',
    ageRange: '11–13',
    imagePath: 'assets/quiz/mystery.jpeg',
    questions: [
      QuizQuestion(question: 'What ancient wonder was in Alexandria?', options: ['Colosseum', 'Great Lighthouse', 'Pantheon', 'Stonehenge'], correctIndex: 1),
      QuizQuestion(question: 'What is a group of crows called?', options: ['Flock', 'Pack', 'Murder', 'Colony'], correctIndex: 2),
      QuizQuestion(question: 'Which country has the most natural lakes?', options: ['USA', 'Russia', 'Canada', 'Brazil'], correctIndex: 2),
      QuizQuestion(question: 'What is the rarest blood type?', options: ['A', 'O', 'AB', 'B'], correctIndex: 2),
      QuizQuestion(question: 'How many sides does a dodecagon have?', options: ['10', '11', '12', '13'], correctIndex: 2),
      QuizQuestion(question: 'What language has the most words?', options: ['French', 'Spanish', 'Mandarin', 'English'], correctIndex: 3),
      QuizQuestion(question: 'Which metal is liquid at room temperature?', options: ['Lead', 'Mercury', 'Tin', 'Zinc'], correctIndex: 1),
      QuizQuestion(question: 'What is the smallest country in the world?', options: ['Monaco', 'San Marino', 'Vatican City', 'Liechtenstein'], correctIndex: 2),
      QuizQuestion(question: 'How many hearts does an octopus have?', options: ['1', '2', '3', '4'], correctIndex: 2),
      QuizQuestion(question: 'What is the hardest natural substance?', options: ['Gold', 'Iron', 'Diamond', 'Quartz'], correctIndex: 2),
    ],
  ),
  QuizCategory(
    title: 'General Knowledge',
    duration: '5 min',
    ageRange: '7–13',
    imagePath: 'assets/quiz/gk.jpeg',
    questions: [
      QuizQuestion(question: 'What is the capital of France?', options: ['London', 'Berlin', 'Paris', 'Rome'], correctIndex: 2),
      QuizQuestion(question: 'How many colors are in a rainbow?', options: ['5', '6', '7', '8'], correctIndex: 2),
      QuizQuestion(question: 'Which is the largest ocean?', options: ['Atlantic', 'Indian', 'Arctic', 'Pacific'], correctIndex: 3),
      QuizQuestion(question: 'What is the fastest land animal?', options: ['Lion', 'Cheetah', 'Horse', 'Leopard'], correctIndex: 1),
      QuizQuestion(question: 'How many continents are there?', options: ['5', '6', '7', '8'], correctIndex: 2),
      QuizQuestion(question: 'What is the longest river in the world?', options: ['Amazon', 'Nile', 'Yangtze', 'Mississippi'], correctIndex: 1),
      QuizQuestion(question: 'Which country has the most population?', options: ['USA', 'India', 'China', 'Russia'], correctIndex: 1),
      QuizQuestion(question: 'What is the tallest mountain?', options: ['K2', 'Kangchenjunga', 'Everest', 'Lhotse'], correctIndex: 2),
      QuizQuestion(question: 'How many days in a leap year?', options: ['364', '365', '366', '367'], correctIndex: 2),
      QuizQuestion(question: 'What is the smallest planet?', options: ['Mars', 'Mercury', 'Venus', 'Pluto'], correctIndex: 1),
    ],
  ),
];

// Play Page

class PlayPage extends StatefulWidget {
  const PlayPage({super.key});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  final TextEditingController _searchController = TextEditingController();
  List<QuizCategory> _filtered = quizCategories;

  void _onSearch(String query) {
    setState(() {
      _filtered = quizCategories
          .where((q) => q.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;
    final cardAspectRatio = screenWidth > 600 ? 0.85 : 0.72;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenWidth * 0.05),
              Text(
                'Learn with Ousia',
                style: GoogleFonts.inter(
                  fontSize: screenWidth * 0.065,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: screenWidth * 0.06),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A3D)
                  : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: GoogleFonts.inter(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search Quiz',
                    hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
                    suffixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.15),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text('No quizzes found',
                            style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 25,
                          childAspectRatio: cardAspectRatio,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) => _QuizCard(
                          category: _filtered[index],
                          onJoin: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuizPage(category: _filtered[index]),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizCategory category;
  final VoidCallback onJoin;

  const _QuizCard({required this.category, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                category.imagePath,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  print('IMAGE ERROR: $error for path: ${category.imagePath}');
                  return Container(
                    color: cs.primaryContainer,
                    child: Icon(Icons.quiz, color: cs.primary, size: 40),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(category.duration,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: cs.onSurfaceVariant)),
                Text('Age: ${category.ageRange}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text('Join',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Quiz Page

class QuizPage extends StatefulWidget {
  final QuizCategory category;
  const QuizPage({super.key, required this.category});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _currentIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _score = 0;

  QuizQuestion get _current => widget.category.questions[_currentIndex];

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedOption = index;
      _answered = true;
      if (index == _current.correctIndex) _score++;
    });
  }

  void _next() {
    if (_currentIndex < widget.category.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    final cs = Theme.of(context).colorScheme;
    final total = widget.category.questions.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cs.surface,
        title: Text(
          _score >= 7 ? '🎉 Great Job!' : _score >= 4 ? '👍 Good Try!' : '😅 Keep Practicing!',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: cs.onSurface),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_score / $total',
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
              textAlign: TextAlign.center,
            ),
            Text('Questions Correct',
                style: GoogleFonts.inter(
                    color: cs.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Exit',
                style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _selectedOption = null;
                _answered = false;
                _score = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              minimumSize: const Size(120, 44),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)
              ),
            ),
            child: Text('Try Again',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _optionBgColor(int index, ColorScheme cs) {
    if (!_answered) return cs.surface;
    if (index == _current.correctIndex) return Colors.green.shade50;
    if (index == _selectedOption) return Colors.red.shade50;
    return cs.surface;
  }

  Color _optionBorderColor(int index, ColorScheme cs) {
    if (!_answered) return cs.outlineVariant;
    if (index == _current.correctIndex) return Colors.green;
    if (index == _selectedOption) return Colors.red;
    return cs.outlineVariant;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.category.questions.length;
    final progress = (_currentIndex + 1) / total;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.title,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/$total',
                style: GoogleFonts.inter(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: cs.surfaceContainerHighest,
            color: cs.primary,
            minHeight: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _current.question,
                      style: GoogleFonts.inter(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_current.options.length, (i) {
                    final isCorrect = _answered && i == _current.correctIndex;
                    final isWrong = _answered && i == _selectedOption && i != _current.correctIndex;
                    return GestureDetector(
                      onTap: () => _selectOption(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenWidth * 0.035,
                        ),
                        decoration: BoxDecoration(
                          color: _optionBgColor(i, cs),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _optionBorderColor(i, cs), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: cs.shadow.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _current.options[i],
                                style: GoogleFonts.inter(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w500,
                                  color: _answered && (i == _current.correctIndex || i == _selectedOption)
                                    ? Colors.black87
                                    : cs.onSurface,
                                ),
                              ),
                            ),
                            if (isCorrect)
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                            if (isWrong)
                              const Icon(Icons.cancel,
                                  color: Colors.red, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  if (_answered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _currentIndex < total - 1
                              ? 'Next Question'
                              : 'See Results',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: screenWidth * 0.04),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}