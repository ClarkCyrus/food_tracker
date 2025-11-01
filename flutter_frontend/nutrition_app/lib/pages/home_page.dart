// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

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

class _NutritionHomePageState extends State<NutritionHomePage> {
  int _currentIndex = 0;
  String? _displayName;
  bool _loadingName = true;

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dailyAgg = {};
  bool _loadingAgg = true;

  bool _uploading = false;
  Map<String, dynamic>? _lastResult;
  Uint8List? _lastImage;
  final ImagePicker _picker = ImagePicker();
  final double previewHeight = 200;

  List<Map<String, dynamic>> _foodItems = []; // add this
  bool _loading = true;


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

    final response = await supabase
        .from('food_intake')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return response;
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadFoodIntakes();
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

  Future<void> _loadFoodIntakes() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;
    final res = await fetchUserFoodIntakes(); // your existing fetch function
    setState(() {
      _foodItems = res;
      _loading = false;
    });
  }

  Future<void> _openCameraAndUpload(BuildContext context) async {
    
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No camera available')));
        return;
      }
      final firstCamera = cameras.first;

      // open camera and wait for bytes from CameraPage
      final Uint8List? bytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => CameraPage(camera: firstCamera)),
      );

      if (bytes == null) return; // user cancelled

      setState(() => _uploading = true);

      try {
        // adjust this depending on environment:
        // Android emulator: 'http://10.0.2.2:8000'
        // iOS simulator: 'http://localhost:8000'
        // Physical device: 'http://<YOUR_PC_LAN_IP>:8000' and run Flask with host="0.0.0.0"
        final serverUrl = defaultServerUrl();

        final processed = await compressForUpload(bytes);

        final result = await uploadImageToServer(
          imageBytes: processed,
          serverBaseUrl: serverUrl,
          multiplier: 1.0,
        ).timeout(const Duration(seconds: 30));

        if (!mounted) return;
        setState(() {
          _lastResult = result;
          _lastImage = bytes;
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  void _onNavTap(int idx) async {
    if (idx == 1) {
      await _openCameraAndUpload(context);
      return;
    }
    if (idx == 2) { // assuming History is the 2nd tab
      Navigator.pushNamed(context, '/history');
    }
    setState(() => _currentIndex = idx);
  }

  Future<void> _addMealDialog() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    String? manualImageUrl;
    Uint8List? manualImageBytes;

    final _mealNameController = TextEditingController();
    final _kcalController = TextEditingController();
    final _proteinController = TextEditingController();
    final _carbsController = TextEditingController();
    final _fatController = TextEditingController();
    final _fiberController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        String? manualImageUrlLocal = manualImageUrl;

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
                            selectionColor: Colors.green.withOpacity(0.25),
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
                    
                    final mealName = _mealNameController.text.trim();
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
                      'label': _mealNameController.text.trim(),
                      'kcal': double.tryParse(_kcalController.text) ?? 0,
                      'protein_g': double.tryParse(_proteinController.text) ?? 0,
                      'carbs_g': double.tryParse(_carbsController.text) ?? 0,
                      'fat_g': double.tryParse(_fatController.text) ?? 0,
                      'fiber_g': double.tryParse(_fiberController.text) ?? 0,
                      'image_url': manualImageUrl,
                    });

                    Navigator.pop(context);
                    await _loadDailyAgg();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Meal added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },    
    );
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

  void _applyPreview(Uint8List bytes) {
    setState(() {
      _lastImage = bytes;
      _lastResult = {
        'label': 'Manual photo (preview)',
        'confidence': 0.0,
        'kcal': '-',
        'protein_g': '-',
        'fat_g': '-',
        'carbs_g': '-',
        'fiber_g': '-'
      };
    });
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
          'kcal': edited['kcal'],
          'protein_g': edited['protein_g'],
          'fat_g': edited['fat_g'],
          'carbs_g': edited['carbs_g'],
          'fiber_g': edited['fiber_g'], 
          'label': foodItem['label'], 
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

  @override
  Widget build(BuildContext context) {
    // Today's nutrition values from Supabase aggregate
    final totalConsumed = (_dailyAgg['kcal_sum'] ?? 0).toInt();
    final proteinConsumed = (_dailyAgg['protein_sum'] ?? 0).toDouble();
    final fatConsumed = (_dailyAgg['fat_sum'] ?? 0).toDouble();
    final fiberConsumed = (_dailyAgg['fiber_sum'] ?? 0).toDouble();
    final carbsConsumed = (_dailyAgg['carbs_sum'] ?? 0).toDouble();

    // Format today's date as "Sep 27, 2025"
    final todayText = "${_selectedDate.day} ${_monthName(_selectedDate.month)}, ${_selectedDate.year}";

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        child: const Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 28,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                
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
                          padding: EdgeInsets.all(12),
                          child: Text('No food intake records found'),
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

                          return FutureBuilder<String>(
                            future: imageFuture,
                            builder: (context, imgSnap) {
                              final imageUrl = imgSnap.data;

                              return GestureDetector(
                                onTap: () => _openEditModal(item), // pass the current item
                                child: Card(
                                  color: const Color.fromARGB(255, 255, 255, 255),
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        if (imageUrl != null)
                                          Container(
                                            width: 96,
                                            height: 96,
                                            margin: const EdgeInsets.only(right: 12),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: ColorFiltered(
                                                colorFilter: ColorFilter.mode(
                                                  const Color.fromARGB(255, 188, 188, 188).withOpacity(0.5),
                                                  BlendMode.darken, // this darkens the image evenly
                                                ),
                                                child: Image.network(imageUrl, fit: BoxFit.cover),
                                              )
                                            ),
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                                        color: Color.fromARGB(255, 153, 153, 153),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // remove button
                                                  IconButton(
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
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '${item['kcal'] ?? '0'} Calories',
                                                style: const TextStyle(
                                                    fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
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
                              );
                            },
                          );
                        },
                      );
                    },
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
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: const Text(
                        'Add Photo (Manual)',
                        style: TextStyle(color: Color.fromARGB(255, 3, 209, 110)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shadowColor: Colors.black.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ).copyWith(
                        overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(MaterialState.pressed)) return const Color(0xFF8FD7B1).withOpacity(0.18);
                          if (states.contains(MaterialState.hovered)) return const Color(0xFF8FD7B1).withOpacity(0.08);
                          return null;
                        }),
                      ),
                      onPressed: () => _pickManualPhoto(context),
                    ),
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

