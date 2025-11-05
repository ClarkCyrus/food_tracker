// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:nutrition_app/main.dart';
import '../pages/camera_page.dart';
import '../services/api_service.dart';
import '../widgets/nutritional_modal.dart';

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

class CircleProgressPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  CircleProgressPainter({
    required this.percent,
    this.trackColor = const Color.fromARGB(0, 31, 175, 122), // example
    this.progressColor = Colors.orangeAccent,
    this.strokeWidth = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final startAngle = -math.pi / 2; // top
    final sweepAngle = 2 * math.pi * percent;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CircleProgressPainter old) => old.percent != percent;
}


class _NutritionHomePageState extends State<NutritionHomePage> {
  int _currentIndex = 0;
  // Load name
  String? _displayName;
  bool _loadingName = true;
  // Load time
  final DateTime _selectedDate = DateTime.now();
  // Load daily
  Map<String, dynamic> _dailyAgg = {};
  Map<String, dynamic>? goals; 
  bool _loadingAgg = true;
  // ignore: unused_field image
  bool _uploading = false;
  // ignore: unused_field
  Map<String, dynamic>? _lastResult;
  // ignore: unused_field
  Uint8List? _lastImage;
  final ImagePicker _picker = ImagePicker();
  final double previewHeight = 200;
  List<Map<String, dynamic>> _foodItems = []; // add this
  // ignore: unused_field intake loading
  bool _loadingIntakes = true;
  // ignore: unused_field  meal l oading
  final ValueNotifier<bool> _isAddPopupOpen = ValueNotifier<bool>(false);
  bool _isAddingMeal = false;
  // ignore: unused_field goals
  double _kcalGoal = 200; // default, can be updated

  String defaultServerUrl() {
    if (kIsWeb) return 'http://localhost:8000'; // web developer machine
    if (Platform.isAndroid) return 'http://10.0.2.2:8000'; // Android emulator
    if (Platform.isIOS) return 'http://localhost:8000'; // iOS simulator
    return 'http://127.0.0.1:8000'; // fallback for desktop/dev
  }

  Future<List<Map<String, dynamic>>> fetchUserFoodIntakes() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Get today's start and end
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final response = await supabase
        .from('food_intake')
        .select()
        .eq('user_id', user.id)
        .gte('created_at', startOfDay.toIso8601String())
        .lte('created_at', endOfDay.toIso8601String())
        .order('created_at', ascending: false);

    return response;
  }
  
  Future<Map<String, dynamic>?> fetchUserGoals() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase
        .from('user_goals')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return response;
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadFoodIntakes();
    _loadDailyAgg();
    _loadGoals();
  }

  /// Loads the user's display name from the Supabase profiles table.
  Future<void> _loadUserName() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
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
          .maybeSingle();

      final first = (profileRes?['first_name'] ?? '') as String;
      final display = (profileRes?['display_name'] ?? '') as String;
      final combined = display.isNotEmpty ? display : (first).trim();
      if (!mounted) return;
      setState(() {
        _displayName = combined.isEmpty ? (user.email ?? 'User') : combined;
        _loadingName = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
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
    if (!mounted) return;
    setState(() => _loadingAgg = false);
  }

  Future<void> _loadFoodIntakes() async {
    if (!mounted) return;
    setState(() => _loadingIntakes = true);
    final res = await fetchUserFoodIntakes(); 

    if (!mounted) return;
    setState(() {
      _foodItems = res;
      _loadingIntakes = false;
    });
  }

  Future<void> _loadGoals () async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('user_goals')
        .select()
        .eq('user_id', userId)
        .maybeSingle(); // returns null if no row exists

    final goals = response;
    if (goals != null && mounted) {
      setState(() {
        _kcalGoal = (goals['kcal_goal'] ?? 200).toDouble();
        /* _proteinGoal = (goals['protein_goal'] ?? 120).toDouble();
        _fatGoal = (goals['fat_goal'] ?? 70).toDouble();
        _fiberGoal = (goals['fiber_goal'] ?? 30).toDouble();
        _carbsGoal = (goals['carbs_goal'] ?? 250).toDouble(); */
      });
    }
}
  
  Future<void> _pickCameraPhoto(BuildContext context) async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );

    if (bytes != null) {
      setState(() => _lastImage = bytes);

      // --- Do your upload and server logic here ---
      try {
        final serverUrl = defaultServerUrl();
        final result = await uploadImageToServer(
          imageBytes: bytes,
          serverBaseUrl: serverUrl,
          multiplier: 1.0,
        );

        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser!;
        final storage = supabase.storage.from('food-images');
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = 'user_${user.id}/$fileName';

        await storage.uploadBinary(filePath, bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'));

        await supabase.from('food_intake').insert({
          'user_id': user.id,
          'source': 'model',
          'label': result['label'],
          'confidence': result['confidence'],
          'kcal': result['kcal'],
          'protein_g': result['protein_g'],
          'fat_g': result['fat_g'],
          'carbs_g': result['carbs_g'],
          'fiber_g': result['fiber_g'],
          'image_url': filePath,
        });

        setState(() => _lastResult = result);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _onNavTap(int idx) async {
    if (idx == 1) {
      _showAddPopup(context);
      return;
    }
    if (idx == 2) { // assuming History is the 2nd tab
      Navigator.pushNamed(context, '/history');
    }
    setState(() => _currentIndex = idx);
  }

  Future<void> _addMealDialog() async {
      if (_isAddingMeal) return; // prevent multiple dialogs
    _isAddingMeal = true;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) { _isAddingMeal = false; return; } 
    Uint8List? manualImageBytes;

    final mealNameController = TextEditingController();
    final kcalController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final fiberController = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (context) {
          String? manualImageUrl;

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text('Add Meal Manually'),
                content: SingleChildScrollView(
                    child: Column(
                      children: [    
                        GestureDetector(
                          onTap: () async {
                            final res = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (res != null && res.files.isNotEmpty) {
                              setStateDialog(() {
                                manualImageBytes = res.files.first.bytes; // local preview
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: manualImageBytes == null
                                ? const Text('Tap to upload meal photo')
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(manualImageBytes!, fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Theme(
                          data: Theme.of(context).copyWith(
                            // caret and selection only
                            textSelectionTheme: TextSelectionThemeData(
                              cursorColor: Colors.green,
                              selectionColor: const Color(0xFF4CAF50).withOpacity(0.25),
                              selectionHandleColor: Colors.green,
                            ),
                            // focused underline and floating label only
                            inputDecorationTheme: InputDecorationTheme(
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.green),
                              ),
                              floatingLabelStyle: TextStyle(color: Colors.green),
                            ),
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: mealNameController,
                                decoration: const InputDecoration(labelText: 'Meal Name'),
                              ),
                              TextField(
                                controller: kcalController,
                                decoration: const InputDecoration(labelText: 'Kcal'),
                                keyboardType: TextInputType.number,
                              ),
                              TextField(
                                controller: proteinController,
                                decoration: const InputDecoration(labelText: 'Protein (g)'),
                                keyboardType: TextInputType.number,
                              ),
                              TextField(
                                controller: carbsController,
                                decoration: const InputDecoration(labelText: 'Carbs (g)'),
                                keyboardType: TextInputType.number,
                              ),
                              TextField(
                                controller: fatController,
                                decoration: const InputDecoration(labelText: 'Fat (g)'),
                                keyboardType: TextInputType.number,
                              ),
                              TextField(
                                controller: fiberController,
                                decoration: const InputDecoration(labelText: 'Fiber (g)'),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                actions: [
                  TextButton(
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.green),
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.green),
                    child: const Text('Add'),
                    onPressed: () async {
                      if (manualImageBytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an image'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      
                      final mealName = mealNameController.text.trim();
                      if (mealName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a meal name'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Upload image to Supabase
                      manualImageUrl = await _uploadThumbnailBytes(manualImageBytes!);

                      if (manualImageUrl == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Image upload failed'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Then insert into DB
                      await supabase.from('food_intake').insert({
                        'user_id': userId,
                        'source': 'manual',
                        'label': mealNameController.text.trim(),
                        'kcal': double.tryParse(kcalController.text) ?? 0,
                        'protein_g': double.tryParse(proteinController.text) ?? 0,
                        'carbs_g': double.tryParse(carbsController.text) ?? 0,
                        'fat_g': double.tryParse(fatController.text) ?? 0,
                        'fiber_g': double.tryParse(fiberController.text) ?? 0,
                        'image_url': manualImageUrl,
                      });

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        await _loadDailyAgg();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Meal added successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },    
      );
    } finally {
      _isAddingMeal = false;
    }
  }
  
  Future<void> _pickManualPhoto(BuildContext context) async {
    try {
      Uint8List? bytes;

      if (kIsWeb) {
        final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
        if (res == null || res.files.isEmpty) return;
        bytes = res.files.first.bytes;
      } else {
        final XFile? file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1280,
          maxHeight: 1280,
        );
        if (file == null) return;
        bytes = await file.readAsBytes();
      }

      if (bytes != null) {
        setState(() => _uploading = true);

        try {
          final serverUrl = defaultServerUrl(); // Flask API
          final result = await uploadImageToServer(
            imageBytes: bytes,
            serverBaseUrl: serverUrl,
            multiplier: 1.0,
          );

          if (!mounted) return;

          // 🟩 Upload image to Supabase PRIVATE bucket
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          if (user == null) throw Exception('User not logged in');

          final storage = supabase.storage.from('food-images');
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'user_${user.id}/$fileName'; // user-specific folder

          await storage.uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

          // Save prediction result to `food_intake`
          await supabase.from('food_intake').insert({
            'user_id': user.id,
            'source': 'model',
            'label': result['label'],
            'confidence': result['confidence'],
            'kcal': result['kcal'],
            'protein_g': result['protein_g'],
            'fat_g': result['fat_g'],
            'carbs_g': result['carbs_g'],
            'fiber_g': result['fiber_g'],
            'image_url': filePath,
          });

          setState(() {
            _lastImage = bytes;
            _lastResult = result;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Food added successfully!'),
              backgroundColor: Colors.green, 
              ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      } else {
        throw Exception('No image data selected');
      }
    } catch (e, st) {
      if (kDebugMode) print('Pick photo error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pick photo failed: $e')),
      );
    }
  }

  Future<String?> _uploadThumbnailBytes(Uint8List bytes) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'user_${user.id}/$fileName';

    final storage = supabase.storage.from('food-images');
    await storage.uploadBinary(
      filePath,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );

    return filePath;
  } catch (e) {
    print('Upload error: $e');
    return null;
  }
}

  Future<Uint8List> compressForUpload(Uint8List data) async {
    // run compression in isolate
    return await compute(_compressIsolate, data);
  }

  Uint8List _compressIsolate(Uint8List data) {
    // Use flutter_image_compress in main isolate only; for pure Dart fallback, return original.
    // If using flutter_image_compress, you would call its API directly (not inside compute),
    // but this is an example placeholder for custom resizing.
    return data;
  }

  Future<void> _openEditModal(Map<String, dynamic> foodItem,) async {

    final signedUrl = await Supabase.instance.client.storage
      .from('food-images')
      .createSignedUrl(foodItem['image_url'], 3600);

    final edited = await showEditNutritionModal(
      context: context,
      initial: foodItem,
      imageUrl: signedUrl, // pre-fill modal fields
    );  

    if (edited != null) {
      // Update Supabase
      await Supabase.instance.client
        .from('food_intake')
        .update({
          'label': edited['label'],
          'kcal': edited['kcal'],
          'protein_g': edited['protein_g'],
          'fat_g': edited['fat_g'],
          'carbs_g': edited['carbs_g'],
          'fiber_g': edited['fiber_g'], 
        })
        .eq('id', foodItem['id']);
      
    await _loadDailyAgg();
    setState(() {});

      // Update local list so UI refreshes immediately
      setState(() {
        final index = _foodItems.indexWhere((f) => f['id'] == foodItem['id']);
        if (index != -1) {
          _foodItems[index] = {..._foodItems[index], ...edited};
        }
      });
    }
  }

  Future<void> _showAddPopup(BuildContext context) async {
    _isAddPopupOpen.value = true;
    // find position of the bottom navigation bar (use the scaffold's context)
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    // compute a position roughly above the center of the bottom nav
    // you can tweak dx/dy offsets to align precisely
    final Size screenSize = overlay.size;
    final Offset anchor = Offset(screenSize.width / 2, screenSize.height - 80);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchor.dx - 100, // left
        anchor.dy - 200, // top (menu appears above anchor)
        anchor.dx + 100, // right
        anchor.dy,       // bottom
      ),
      items: [
        PopupMenuItem<String>(
          value: 'add_meal',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add, color: Color.fromARGB(255, 3, 209, 110)),
            title: const Text('Add Meal Manually'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'pick_photo',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library, color: Color.fromARGB(255, 3, 209, 110)),
            title: const Text('Add Photo'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'take_photo',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.camera_alt, color: Color.fromARGB(255, 3, 209, 110)),
            title: const Text('Take A Photo'),
          ),
        ),
      ],
      color: const Color.fromARGB(236, 255, 255, 255),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    _isAddPopupOpen.value = false;

    // handle selection
    switch (selected) {
      case 'add_meal':
        _addMealDialog();
        break;
      case 'pick_photo':
        _pickManualPhoto(context);
        break;
      case 'take_photo':
        _pickCameraPhoto(context);
        break;
      default:
        break;
    }
  }

  Future<void> _saveGoals({required double kcalGoal}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
    .from('user_goals')
    .upsert(
      [
        {
        'user_id': userId,
        'kcal_goal': kcalGoal,
        }
      ],
      onConflict: 'user_id',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal Set!'), backgroundColor: Colors.green),
      );
    }
  }

  Widget buildCustomAppBar() {
    return Container(
      height: 70,
      color: const Color.fromARGB(255, 255, 255, 255),
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            child: Center(
              child: Image.asset(
                'assets/app_logo2.png',
                width: 70,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
                navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
              } catch (e) {
                ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                  SnackBar(content: Text('Logout failed: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    // Today's goals values from Supabase aggregate
    final kcalGoal = (goals?['kcal_goal'] ?? 200).toDouble();
    final proteinGoal = (goals?['protein_goal'] ?? 100).toDouble();
    final fatGoal = (goals?['fat_goal'] ?? 100).toDouble();
    final fiberGoal = (goals?['fiber_goal'] ?? 100).toDouble();
    final carbsGoal = (goals?['carbs_goal'] ?? 100).toDouble();


    // Today's nutrition values from Supabase aggregate
    final totalConsumed = (_dailyAgg['kcal_sum'] ?? 0).toInt();
    final proteinConsumed = (_dailyAgg['protein_sum'] ?? 0).toDouble();
    final fatConsumed = (_dailyAgg['fat_sum'] ?? 0).toDouble();
    final fiberConsumed = (_dailyAgg['fiber_sum'] ?? 0).toDouble();
    final carbsConsumed = (_dailyAgg['carbs_sum'] ?? 0).toDouble();

    // Format today's date as "Sep 27, 2025"
    final todayText = "${_selectedDate.day} ${_monthName(_selectedDate.month)}, ${_selectedDate.year}";
    double remaining = _kcalGoal - totalConsumed;
    // complete flag or label

    final bool isComplete = totalConsumed >= _kcalGoal; // true when eaten is equal or greater than goal

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right:16, top: 4, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                buildCustomAppBar(),
                // Header with user name from Supabase profiles
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), // adjust as needed
                  child: Row(
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
                    ],
                  ),
                ),

                  const SizedBox(height: 12),
                  
                  // Redesigned Today's Nutrients Card
                  // Uses today's nutrition intake from Supabase
                  SizedBox(
                    height: 310,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),   
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(0, 0, 0, 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
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
                                          const Text('Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.orangeAccent.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12),
                                          ),  
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.center, // horizontal center
                                            children: [
                                              const Spacer(), // push content to vertical center
                                              // Progress circle with text
                                              Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  CustomPaint(
                                                    size: const Size(120, 120),
                                                    painter: CircleProgressPainter(
                                                      percent: (totalConsumed / _kcalGoal).clamp(0.0, 1.0),
                                                      trackColor: Colors.orangeAccent.withOpacity(0.12),
                                                      progressColor: Colors.orangeAccent,
                                                      strokeWidth: 12,
                                                    ),
                                                  ),
                                                  Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text('$_kcalGoal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                      Text(isComplete ? 'Completed' : '${remaining.toStringAsFixed(0)} until'),
                                                      const Text('target', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Bottom: small fire icon + calories
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orangeAccent.withOpacity(0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 14),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '$totalConsumed Kcal',
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                  ),
                                                  // inside build where you currently have the IconButton
                                                   GestureDetector(
                                                    onTap: () async {
                                                      // your dialog logic here
                                                      final TextEditingController controller =
                                                          TextEditingController(text: _kcalGoal.toInt().toString());
                                                      final result = await showDialog<double>(
                                                        context: context,
                                                        builder: (ctx) {
                                                          double? temp = _kcalGoal;
                                                          return StatefulBuilder(builder: (ctx, setDialogState) {
                                                            return Theme(
                                                              data: Theme.of(ctx).copyWith(
                                                                textSelectionTheme: TextSelectionThemeData(
                                                                  cursorColor: Colors.green,
                                                                  selectionColor: const Color(0x404CAF50),
                                                                  selectionHandleColor: Colors.green,
                                                                ),
                                                                inputDecorationTheme: const InputDecorationTheme(
                                                                  focusedBorder: UnderlineInputBorder(
                                                                    borderSide: BorderSide(color: Colors.green),
                                                                  ),
                                                                  floatingLabelStyle: TextStyle(color: Colors.green),
                                                                ),
                                                              ),
                                                              child: AlertDialog(
                                                                title: const Text('Adjust Goal Kcal'),
                                                                content: TextField(
                                                                  keyboardType: TextInputType.number,
                                                                  controller: controller,
                                                                  onChanged: (v) => setDialogState(() => temp = double.tryParse(v)),
                                                                  autofocus: true,
                                                                  decoration: const InputDecoration(labelText: 'Kcal'),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.of(ctx).pop(),
                                                                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                                                                    child: const Text('Cancel'),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed: () async {
                                                                      if (temp == null || temp! <= 0) return;
                                                                        Navigator.of(ctx).pop(temp);
                                                                      },
                                                                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                                                                    child: const Text('Save'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          });
                                                        },
                                                      );
                                                      if (result != null && mounted) {
                                                        setState(() => _kcalGoal = result);
                                                        await _saveGoals(kcalGoal: _kcalGoal); 
                                                      }
                                                    },
                                                    child: Icon(
                                                      Icons.chevron_right,
                                                      color: Colors.grey.shade400,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              /* const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Set Goals',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                                  ),
                                                  // inside build where you currently have the IconButton

                                                ],
                                              ),   */                                 
                                              const Spacer(),
                                            ],
                                          ),
                                        ),
                                      ),                        
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // RIGHT: four nutrient mini-cards stacked (Carbs, Protein, Fat, Fiber)
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      // Carbs
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.12), shape: BoxShape.circle),
                                                child: Icon(Icons.energy_savings_leaf, color: Colors.indigoAccent, size: 18),
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text('${carbsConsumed.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                                  const Text('Carbs', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                ],
                                              ),
                                              const Spacer(),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

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

                  const SizedBox(height: 14),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4), // adjust value as needed
                    child: Text(
                      'Today\'s Meals',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 4, 4, 4),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchUserFoodIntakes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text('No food eaten today. Tap the + button to add some!'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final imagePath = item['image_url'] ?? '';
                          final imageFuture = Supabase.instance.client.storage
                              .from('food-images')
                              .createSignedUrl(imagePath, 60 * 60);

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 1000 + (index * 70)), // stagger for smoothness
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)), // slides up gently
                                  child: child,
                                ),
                              );
                            },
                          child: FutureBuilder<String>(
                            future: imageFuture,
                            builder: (context, imgSnap) {
                              final imageUrl = imgSnap.data;

                              return GestureDetector(
                                onTap: () => _openEditModal(item),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0), // 👈 add horizontal too
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),   
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color.fromRGBO(0, 0, 0, 0.10),
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ), // pass the current item
                                child: Card(
                                  color: const Color.fromARGB(255, 255, 255, 255),
                                  elevation: 0, //  Adjust for stronger or softer shadow
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center, 
                                      children: [
                                        Container(
                                          width: 96,
                                          height: 96,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: imageUrl == null
                                            ? Image.asset(
                                                'assets/white.png', // 👈 same placeholder you use before
                                                fit: BoxFit.cover,
                                              )
                                            : FadeInImage.assetNetwork(
                                                placeholder: 'assets/white.png',
                                                image: imageUrl!,
                                                fit: BoxFit.cover,
                                                fadeInDuration: const Duration(milliseconds: 150),
                                                fadeOutDuration: const Duration(milliseconds: 150),
                                                imageErrorBuilder: (context, error, stackTrace) => const Center(
                                                  child: Icon(Icons.image_not_supported_outlined,
                                                      color: Colors.grey, size: 28),
                                                ),
                                              ),
                                        ),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min, 
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      (item['label'] ?? 'Unknown')
                                                          .toString()
                                                          .replaceAll('_', ' ')
                                                          .split(RegExp(r'\s+'))
                                                          .map((w) =>
                                                              w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
                                                          .join(' '),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color.fromARGB(255, 94, 94, 94),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    item['created_at'] != null
                                                      ? DateFormat('hh:mm a').format(DateTime.parse(item['created_at']).toLocal())
                                                      : '',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                  // remove button
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4, right: 0), // adjust value if needed
                                                    child: SizedBox(
                                                      width: 24, height: 24,
                                                      child :IconButton(
                                                        icon: const Icon(Icons.close, size: 18, color: Color.fromARGB(255, 186, 186, 186)),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () async {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (_) => AlertDialog(
                                                              title: const Text('Remove Item', style: TextStyle(color: Colors.red)),
                                                              content: Text.rich(
                                                                TextSpan(
                                                                  text: 'This action cannot be undone!\nAre you sure you want to remove ',
                                                                  children: [                                 
                                                                    TextSpan(text: "${item['label'] ?? 'this food'}", style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                                                                    const TextSpan(text: '?'),
                                                                  ],
                                                                ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, false), 
                                                                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                                                                  child: const Text('Cancel')
                                                                ),
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(context, true), 
                                                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                                  child: const Text('Remove')
                                                                ),
                                                              ],
                                                          ),
                                                        );

                                                        if (confirm == true) {
                                                          await Supabase.instance.client
                                                              .from('food_intake')
                                                              .delete()
                                                              .eq('id', item['id']);
                                                            
                                                          await _loadDailyAgg();
                                                          setState(() {});

                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('Item removed successfully'),
                                                                backgroundColor: Colors.red,
                                                                behavior: SnackBarBehavior.floating,
                                                              ),
                                                            );
                                                          }
                                                          setState(() {});
                                                        }
                                                      },
                                                    ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                                    
                                              Text(
                                                '${item['kcal'] ?? '0'} Calories',
                                                style: const TextStyle(
                                                    fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                            
                                              const SizedBox(height: 4),
                                              
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                   Expanded(
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.indigoAccent.withOpacity(0.12),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          padding: const EdgeInsets.all(6),
                                                          child: const Icon(Icons.energy_savings_leaf, color: Colors.indigoAccent, size: 12),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${item['carbs_g'] ?? '0'} g',
                                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.redAccent.withOpacity(0.12),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          padding: const EdgeInsets.all(6),
                                                          child: const Icon(Icons.fitness_center, color: Colors.redAccent, size: 12),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${item['protein_g'] ?? '0'} g',
                                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                        ),
                                                      ],
                                                    ),
                                                  ),                                              
                                                ],
                                              ),
                                              
                                              const SizedBox(height: 4),

                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [                                               
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.orangeAccent.withOpacity(0.12),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          padding: const EdgeInsets.all(6),
                                                          child: const Icon(Icons.opacity, color: Colors.orangeAccent, size: 12),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${item['fat_g'] ?? '0'} g',
                                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.green.withOpacity(0.12),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          padding: const EdgeInsets.all(6),
                                                          child: const Icon(Icons.grass, color: Colors.green, size: 12),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${item['fiber_g'] ?? '0'} g',
                                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
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
                            },
                          ),
                          );
                        },
                      );
                    },
                  ),      
                ],
              ),
            ),
          ),
        ),
      // replace your bottomNavigationBar assignment with this block
      // simple: ClipRRect + Container to add radius and optional shadow
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(50),
          topRight: Radius.circular(50),
        ),
        clipBehavior: Clip.none,
        child: Container(
          height: 85,
          decoration: BoxDecoration(
            color: Colors.white, // nav background
            boxShadow: [
              BoxShadow(color: const Color.fromARGB(31, 17, 17, 17), blurRadius: 8),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor:  Colors.grey,
            unselectedItemColor: Colors.grey,
            backgroundColor: const Color.fromARGB(255, 249, 249, 249),
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, color: const Color.fromARGB(255, 3, 209, 110),),
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
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isAddPopupOpen,
                        builder: (context, isOpen, child) {
                          return Container(
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
                            child: Icon(
                              isOpen ? Icons.close : Icons.add,
                              color: Colors.white,
                              size: 28,
                            ),
                          );
                        },
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

