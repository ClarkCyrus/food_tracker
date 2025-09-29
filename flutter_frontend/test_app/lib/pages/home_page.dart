// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';
import '../pages/camera_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  int _currentIndex = 0;
  String? _displayName;
  bool _loadingName = true;

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dailyAgg = {};
  bool _loadingAgg = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDailyAgg();
  }

  /// Loads the user's display name from the Supabase profiles table.
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

    try {
      // Query the profiles table for the user's display name
      final profileRes = await supabase
          .from('profiles')
          .select('first_name, display_name, avatar_url')
          .eq('user_id', user.id)
          .single();

      final first = (profileRes['first_name'] ?? '') as String;
      final display = (profileRes['display_name'] ?? '') as String;
      final combined = display.isNotEmpty ? display : ('$first').trim();
      setState(() {
        _displayName = combined.isEmpty ? (user.email ?? 'User') : combined;
        _loadingName = false;
      });
    } catch (e) {
      setState(() {
        _displayName = user.email ?? 'User';
        _loadingName = false;
      });
    }
  }

  /// Loads today's nutrition intake using the custom aggregate function.
  Future<void> _loadDailyAgg([DateTime? date]) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final dateStr = (date ?? DateTime.now()).toIso8601String().substring(0, 10);

    if (userId == null) {
      setState(() {
        _loadingAgg = false;
      });
      return;
    }

    try {
      // Use the custom RPC for daily aggregates
      final res = await supabase.rpc('daily_nutrient_agg', params: {
        'user_id': userId,
        'meal_date': dateStr,
      });
      // Use res directly, not res.data
      _dailyAgg = res.isNotEmpty ? res[0] : {};
    } catch (e) {
      _dailyAgg = {};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load daily aggregates: $e')),
      );
    }
    setState(() => _loadingAgg = false);
  }

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

  void _onNavTap(int idx) async {
    if (idx == 1) {
      // Middle button: Open camera
      await _openCamera(context);
      // Do not change _currentIndex, stay on home after camera
      return;
    }
    setState(() => _currentIndex = idx);
  }

  Future<void> _addMealDialog() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final _mealNameController = TextEditingController();
    final _kcalController = TextEditingController();
    final _proteinController = TextEditingController();
    final _carbsController = TextEditingController();
    final _fatController = TextEditingController();
    final _fiberController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Meal Manually'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _mealNameController,
                decoration: const InputDecoration(labelText: 'Meal Name'),
              ),
              TextField(
                controller: _kcalController,
                decoration: const InputDecoration(labelText: 'Kcal'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _proteinController,
                decoration: const InputDecoration(labelText: 'Protein (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _carbsController,
                decoration: const InputDecoration(labelText: 'Carbs (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _fatController,
                decoration: const InputDecoration(labelText: 'Fat (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _fiberController,
                decoration: const InputDecoration(labelText: 'Fiber (g)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Add'),
            onPressed: () async {
              final now = DateTime.now();
              await supabase.from('nutrition_intake').insert({
                'user_id': userId,
                'meal_date': now.toIso8601String().substring(0, 10),
                'meal_name': _mealNameController.text,
                'kcal': double.tryParse(_kcalController.text) ?? 0,
                'protein_g': double.tryParse(_proteinController.text) ?? 0,
                'carbs_g': double.tryParse(_carbsController.text) ?? 0,
                'fat_g': double.tryParse(_fatController.text) ?? 0,
                'fiber_g': double.tryParse(_fiberController.text) ?? 0,
              });
              Navigator.pop(context);
              await _loadDailyAgg(); // Refresh nutrients card
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Today's nutrition values from Supabase aggregate
    final totalConsumed = (_dailyAgg['kcal_sum'] ?? 0).toInt();
    final proteinConsumed = (_dailyAgg['protein_sum'] ?? 0).toDouble();
    final fatConsumed = (_dailyAgg['fat_sum'] ?? 0).toDouble();
    final fiberConsumed = (_dailyAgg['fiber_sum'] ?? 0).toDouble();

    // Format today's date as "Sep 27, 2025"
    final todayText = "${_selectedDate.day} ${_monthName(_selectedDate.month)}, ${_selectedDate.year}";

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user name from Supabase profiles
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
            
              // Redesigned Today's Nutrients Card
              // Uses today's nutrition intake from Supabase
              SizedBox(
                height: 300,
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
                  padding: const EdgeInsets.all(16),
                  child: _loadingAgg
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: [
                            // LEFT: Calories + date
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // header row with title and today's date (no picker)
                                  Row(
                                    children: [
                                      const Text('Intake', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      Text(
                                        todayText,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // big calorie block
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.12), shape: BoxShape.circle),
                                            child: Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '$totalConsumed',
                                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                              ),
                                              const Text('Kcal', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                            ],
                                          ),
                                          const Spacer(),
                                          Icon(Icons.chevron_right, color: Colors.grey.shade400),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // RIGHT: three nutrient mini-cards stacked (Protein, Fat, Fiber)
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  // Protein
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), shape: BoxShape.circle),
                                            child: Icon(Icons.fitness_center, color: Colors.redAccent, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('${proteinConsumed.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const Text('Protein', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Fat
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.12), shape: BoxShape.circle),
                                            child: Icon(Icons.opacity, color: Colors.orangeAccent, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('${fatConsumed.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const Text('Fat', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Fiber
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
                                            child: Icon(Icons.grass, color: Colors.green, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('${fiberConsumed.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const Text('Fiber', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                          const Spacer(),
                                        ],
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

              // Add Meal Button (below nutrients card)
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 20), // new icon
                  label: const Text(
                    'Add Meal Manually',
                    style: TextStyle(color: Color.fromARGB(255, 3, 209, 110)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255), // button fill color
                    foregroundColor: const Color.fromARGB(255, 0, 0, 0), // icon + label color
                    shadowColor: Colors.black.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ).copyWith(
                    // custom overlay (pressed / splash) color
                    overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(MaterialState.pressed)) return const Color(0xFF8FD7B1).withOpacity(0.18);
                      if (states.contains(MaterialState.hovered)) return const Color(0xFF8FD7B1).withOpacity(0.08);
                      return null;
                    }),
                  ),
                  onPressed: _addMealDialog,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      
      // replace your bottomNavigationBar assignment with this block
      // simple: ClipRRect + Container to add radius and optional shadow
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        clipBehavior: Clip.none,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white, // nav background
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color.fromARGB(255, 3, 209, 110),
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: SizedBox(
                  height: 20,
                  width: 56,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -32),
                      child: OverflowBox(
                        maxWidth: 80,
                        maxHeight: 80,
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 3, 209, 110),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
            ],
            onTap: _onNavTap,
          ),
        ),
      ),

    );
  }

  // Helper function for month name
  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

