import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({Key? key}) : super(key: key);

  @override
  _FoodHistoryPageState createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  final supabase = Supabase.instance.client;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> foodHistory = [];
  bool isLoading = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFoodHistory();
  }

  Future<void> _loadFoodHistory() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => isLoading = true);

    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await supabase
        .from('food_intake')
        .select()
        .eq('user_id', userId)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String())
        .order('created_at', ascending: true);

    final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

    // 🔥 Preload signed URLs before showing anything
    for (var item in data) {
      final imageUrl = await _getSignedImageUrl(item['image_url']);
      item['signed_url'] = imageUrl;
    }

    setState(() {
      foodHistory = data;
      isLoading = false;
    });

  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
       builder: (context, child) {
        return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Colors.green,              // header & selected date
            onPrimary: Colors.white,            // header text
            surface: Colors.white,              // calendar background
            onSurface: Colors.black,            // unselected date text
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,   
            ),
          ),
        ),
        child: child!,
      );
       }
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadFoodHistory();
    }
  }

  /// Returns a signed URL (valid for 1 hour) if bucket is private
  Future<String?> _getSignedImageUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final response = await supabase.storage.from('food-images').createSignedUrl(path, 3600);
      return response;
    } catch (e) {
      print('Error creating signed URL: $e');
      return null;
    }
  }

  void _onNavTap(int idx) async {
    if (idx == 0) { 
      Navigator.pushNamed(context, '/home');;
      return;
    }
    if (idx == 1) { 
      Navigator.pushNamed(context, '/home',  arguments: {'_showAddPopup(context)': true});
      return;
    }
    setState(() => _currentIndex = idx);
  }

  String _titleCaseLabel(String raw) {
    final r = raw.replaceAll('_', ' ').trim();
    if (r.isEmpty) return 'Unknown';
    return r
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        centerTitle: true,
        title: const Text(
          'History',   
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : foodHistory.isEmpty
              ? const Center(child: Text('No food entries for this date'))
              : ListView.builder(
                  itemCount: foodHistory.length,
                  itemBuilder: (context, index) {
                    final food = foodHistory[index];

                    return FutureBuilder<String?>(
                      future: _getSignedImageUrl(food['image_url']),
                      builder: (context, snapshot) {
                        final imageUrl = snapshot.data;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: const Color.fromARGB(255, 255, 255, 255),
                          elevation: 4, //  Adjust for stronger or softer shadow
                          shadowColor: const Color.fromRGBO(0, 0, 0, 0.55), //  softer, diffused shadow
                          child: ListTile(
                            leading: food['signed_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      food['signed_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
                                    ),
                                  )
                                : const Icon(Icons.fastfood),
                            title: Text(_titleCaseLabel(food['label'] ?? 'Unknown Meal')),
                            subtitle: Text(
                                'Kcal: ${food['kcal'] ?? 0}, Protein: ${food['protein_g'] ?? 0}g\nCarbs: ${food['carbs_g'] ?? 0}g, Fat: ${food['fat_g'] ?? 0}g'),
                            isThreeLine: true,
                            trailing: Text(DateFormat('hh:mm a').format(DateTime.parse(food['created_at']).toLocal())),
                          ),
                        );
                        
                      },
                    );
                  },
                ),

                bottomNavigationBar: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  clipBehavior: Clip.none,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: const Color.fromARGB(31, 71, 71, 71), blurRadius: 8),
                      ],
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: Colors.grey,
                      unselectedItemColor: Colors.grey,
                      backgroundColor: const Color.fromARGB(255, 249, 249, 249),
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
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          label: '',
                        ),

                        BottomNavigationBarItem(
                          icon: Icon(Icons.history, color: const Color.fromARGB(255, 3, 209, 110)),
                          label: 'History',
                        ),
                      ],
                      onTap: _onNavTap,
                    ),
                  ),
                ),

    );
  }
}
