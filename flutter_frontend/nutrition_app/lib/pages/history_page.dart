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

    setState(() {
      foodHistory = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food History'),
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
                          child: ListTile(
                            leading: imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
                                    ),
                                  )
                                : const Icon(Icons.fastfood),
                            title: Text(food['label'] ?? 'Unknown Meal'),
                            subtitle: Text(
                                'Kcal: ${food['kcal'] ?? 0}, Protein: ${food['protein_g'] ?? 0}g\nCarbs: ${food['carbs_g'] ?? 0}g, Fat: ${food['fat_g'] ?? 0}g'),
                            isThreeLine: true,
                            trailing: Text(DateFormat.Hm().format(DateTime.parse(food['created_at']))),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
