// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';
import '../pages/camera_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your project URL and anon key
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    anonKey: 'your-anon-key',
  );

  runApp(const MyApp()); 
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const NutritionHomePage(), 
    );
  }
}

class NutritionHomePage extends StatefulWidget {
  const NutritionHomePage({super.key}); 

  @override
  _NutritionHomePageState createState() => _NutritionHomePageState();
}

class _NutritionHomePageState extends State<NutritionHomePage> {
  int _currentIndex = 1; // default to Nutrition
  String? _displayName;
  bool _loadingName = true;

  // Sample nutrient data
  final List<_Nutrient> _nutrients = [
    _Nutrient(
      icon: Icons.fitness_center,
      name: 'Protein',
      consumed: 60,
      goal: 100,
      color: Colors.redAccent,
    ),
    _Nutrient(
      icon: Icons.bubble_chart,
      name: 'Carbs',
      consumed: 180,
      goal: 250,
      color: Colors.blueAccent,
    ),
    _Nutrient(
      icon: Icons.opacity,
      name: 'Fat',
      consumed: 55,
      goal: 80,
      color: Colors.orangeAccent,
    ),
    _Nutrient(
      icon: Icons.grass,
      name: 'Fiber',
      consumed: 20,
      goal: 30,
      color: Colors.greenAccent,
    ),
  ];

  // Sample recent meals
  final List<_Meal> _meals = [
    _Meal(name: 'Chicken Salad', calories: 320, time: '7:45 AM'),
    _Meal(name: 'Oatmeal Bowl', calories: 250, time: '10:30 AM'),
    _Meal(name: 'Fruit Snack', calories: 87, time: '2:00 PM'),
  ];

  // Example burn goal for progress
  final int _burnGoal = 800;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _displayName = 'Guest';
        _loadingName = false;
      });
      return;
    }

    // Try metadata first
    final metadataName = user.userMetadata?['full_name'] as String?;
    if (metadataName != null && metadataName.isNotEmpty) {
      setState(() {
        _displayName = metadataName;
        _loadingName = false;
      });
      return;
    }

    // Query profiles table for richer user info
    try {
      final profile = await supabase
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && profile is Map) {
        final first = (profile['first_name'] ?? '') as String;
        final last = (profile['last_name'] ?? '') as String;
        final combined = ('$first $last').trim();
        setState(() {
          _displayName = combined.isEmpty ? user.email ?? 'User' : combined;
          _loadingName = false;
        });
        return;
      }
    } catch (_) {
      // ignore and fallback to email
    }

    setState(() {
      _displayName = user.email ?? 'User';
      _loadingName = false;
    });
  }

  int _totalConsumedCalories() => _meals.fold<int>(0, (p, m) => p + m.calories);

  Future<void> _openCamera(BuildContext context) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera available')),
        );
        return;
      }
      final firstCamera = cameras.first;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CameraPage(camera: firstCamera),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalConsumed = _totalConsumedCalories();
    final burned = 245; // replace with real activity data when available

    // Calculate today's fat and protein from _nutrients list
    final fatNutrient = _nutrients.firstWhere((n) => n.name == 'Fat', orElse: () => _Nutrient(icon: Icons.opacity, name: 'Fat', consumed: 0, goal: 1, color: Colors.orangeAccent));
    final proteinNutrient = _nutrients.firstWhere((n) => n.name == 'Protein', orElse: () => _Nutrient(icon: Icons.fitness_center, name: 'Protein', consumed: 0, goal: 1, color: Colors.redAccent));
    final fatConsumed = fatNutrient.consumed;
    final proteinConsumed = proteinNutrient.consumed;

    final double halfWidth = (MediaQuery.of(context).size.width - 32) / 2; // 16 padding each side

    return Scaffold(
      backgroundColor: Color(0xF2F2F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loadingName ? 'Hi,' : 'Hi, ${_displayName ?? 'User'}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF032221),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Track your nutrients today',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Calore Card
              CalorieCard(calories: 1536, onTap: () { /* navigate */ }),

              const SizedBox(height: 16),

              // Add a button to open the camera
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Open Camera'),
                onPressed: () => _openCamera(context),
              ),

              // Redesigned Today's Nutrients Card
              // Place this inside your build method where halfWidth, totalConsumed, fatConsumed are defined.
              SizedBox(
                height: 300,
                width: halfWidth,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Header for Intake
                      const Text(
                        'Intake',
                        style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 0, 0)),
                      ),
  
                      const SizedBox(height: 12),
                      
                      // Top block (Kcal) — styled the same way as the bottom Fat block
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 64, 64).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            // circular icon background
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
                            ),

                            const SizedBox(width: 12),

                            // value + unit and label
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$totalConsumed',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'Kcal',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),

                            const Spacer(),

                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Fat block (identical style to Kcal block)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            // circular icon background
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.opacity, color: Colors.orangeAccent, size: 18),
                            ),

                            const SizedBox(width: 12),

                            // value + unit and label
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$fatConsumed',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'g/Fat',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),

                            const Spacer(),

                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ],
                        ),
                      ),

                      const Spacer(),

                    ],
                  ),
                ),
              ),


              const SizedBox(height: 24),

              // Today's Nutrients horizontal list (nutrient cards)
              Text(
                "Today's Nutrients",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _nutrients.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final n = _nutrients[i];
                    return _NutrientCard(nutrient: n);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Recent Meals Section
              const Text(
                'Recent Meals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: ListView.separated(
                  itemCount: _meals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final meal = _meals[idx];
                    return _MealCard(meal: meal);
                  },
                ),
              ),

            ],
          ),
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade600,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            label: 'Nutrition',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        onTap: (idx) => setState(() => _currentIndex = idx),
      ),
    );
  }
}

// Data model for a nutrient
class _Nutrient {
  final IconData icon;
  final String name;
  final double consumed;
  final double goal;
  final Color color;

  _Nutrient({
    required this.icon,
    required this.name,
    required this.consumed,
    required this.goal,
    required this.color,
  });
}

// Card widget for a single nutrient
class _NutrientCard extends StatelessWidget {
  final _Nutrient nutrient;

  const _NutrientCard({required this.nutrient});

  @override
  Widget build(BuildContext context) {
    final pct = (nutrient.consumed / nutrient.goal).clamp(0.0, 1.0);
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: nutrient.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(nutrient.icon, color: nutrient.color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            nutrient.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${nutrient.consumed.toInt()}g / ${nutrient.goal.toInt()}g',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            color: nutrient.color,
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}

// Data model for a meal
class _Meal {
  final String name;
  final int calories;
  final String time;
  _Meal({
    required this.name,
    required this.calories,
    required this.time,
  });
}

// Card widget for a recent meal
class _MealCard extends StatelessWidget {
  final _Meal meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.green.shade50,
            child: Icon(Icons.restaurant, color: Colors.green.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  meal.time,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '${meal.calories} kcal',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )
        ],
      ),
    );
  }
}

class CalorieCard extends StatelessWidget {
  final int calories;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  const CalorieCard({
    Key? key,
    required this.calories,
    this.onTap,
    this.backgroundColor = const Color(0xFF00E58D),
    this.iconColor = const Color(0xFFFFFFFF),
    this.textColor = Colors.white,
  }) : super(key: key);

  String get formattedCalories {
    // Use double quotes for the outer string so the RegExp raw string works correctly
    return "${calories.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} Kcal";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formattedCalories,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: textColor.withOpacity(0.9),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
