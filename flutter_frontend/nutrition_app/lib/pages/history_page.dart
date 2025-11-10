import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({Key? key}) : super(key: key);

  @override
  _FoodHistoryPageState createState() => _FoodHistoryPageState();
}

class SevenDayLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData; // [{'day':'Mon','kcal':1200},...]

  const SevenDayLineChart({required this.weeklyData, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160, // enough for chart + labels
      child: Column(
        children: [
          // Top Row
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Calorie',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'This Week',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 26, right: 8, bottom: 16),
              child: CustomPaint(
                painter: _SevenDayLineChartPainter(weeklyData),
                child: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for macro display
class _MacroColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroColumn({
    required this.label,
    required this.value,
    this.color = Colors.blue,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // small colored bar
        Container(
          width: 6,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        // text column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              '$value g',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

          ],
        ),
      ],
    );
  }
}

class _SevenDayLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  _SevenDayLineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = const Color(0xFF03D16E)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintCircle = Paint()
      ..color = const Color(0xFF03D16E)
      ..style = PaintingStyle.fill;

    final paintFill = Paint()
      ..color = const Color(0xFF03D16E).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final double widthStep = size.width / (data.length - 1);
    final double maxVal = data.fold<double>(
        0, (prev, e) => (e['kcal'] as double) > prev ? (e['kcal'] as double) : prev);

    final path = Path();
    final pathFill = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * widthStep;
      final y = maxVal == 0
          ? size.height
          : size.height - ((data[i]['kcal'] as double) / maxVal) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        pathFill.moveTo(x, size.height);
        pathFill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        pathFill.lineTo(x, y);
      }
    }

    pathFill.lineTo(size.width, size.height);
    pathFill.close();

    canvas.drawPath(pathFill, paintFill);
    canvas.drawPath(path, paintLine);

    // Draw points
    for (int i = 0; i < data.length; i++) {
      final x = i * widthStep;
      final y = maxVal == 0
          ? size.height
          : size.height - ((data[i]['kcal'] as double) / maxVal) * size.height;
      canvas.drawCircle(Offset(x, y), 4, paintCircle);
    }

    // Draw day labels safely inside the container
    final textStyle = const TextStyle(color: Colors.black54, fontSize: 10);
    final double horizontalPadding = 0; // 👈 padding on both sides

    for (int i = 0; i < data.length; i++) {
      // compute x within padded area
      final x = horizontalPadding + (i * (size.width - 2 * horizontalPadding) / (data.length - 1));

      final String label = data[i]['day'].toString();

      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );

      tp.layout();

      // draw label within visible canvas
      final dx = x - tp.width / 2;
      final dy = size.height + 6; // a little upward padding from bottom
      tp.paint(canvas, Offset(dx, dy));
    }

      const double yLabelRightPadding = -24; 

      // ✅ Y-axis (kcal) labels on the left
      final yLabelStyle = const TextStyle(color: Colors.black54, fontSize: 8);
      const int divisions = 4; // e.g. 0, 500, 1000, 1500, 2000
      final double stepValue = maxVal / divisions;

      for (int i = 0; i <= divisions; i++) {
        final value = (stepValue * i).round();
        final y = size.height - (i / divisions) * size.height;

        final tp = TextPainter(
          text: TextSpan(text: value.toString(), style: yLabelStyle),
          textAlign: TextAlign.right,
          textDirection: ui.TextDirection.ltr,
        )..layout();

       tp.paint(canvas, Offset(yLabelRightPadding, y - tp.height / 2)); // left side
      }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  final supabase = Supabase.instance.client;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> foodHistory = [];
  bool isLoading = false;
  bool isLoadingWeek = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    _loadFoodHistory();
    _loadWeekHistory();
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

  Future<void> _loadWeekHistory() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => isLoadingWeek = true);

    // Get Monday → Sunday of selected week
    final monday = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    // Only select calories
    final response = await supabase
        .from('food_intake')
        .select('created_at, kcal')
        .eq('user_id', userId)
        .gte('created_at', monday.toIso8601String())
        .lte('created_at', sunday.toIso8601String())
        .order('created_at', ascending: true);

    final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

    setState(() {
      _prepareWeeklyCalories(data); // prepares Mon → Sun chart
      isLoadingWeek = false;
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
      _loadWeekHistory();
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

  List<Map<String, dynamic>> weeklyCalories = [];
  void _prepareWeeklyCalories(List<Map<String, dynamic>> rawData) {
    if (rawData.isEmpty) {
      weeklyCalories = [];
      return;
    }

    // 1️⃣ Find the Monday of the selected week
    final selected = selectedDate;
    final monday = selected.subtract(Duration(days: selected.weekday - 1)); // weekday: Mon=1
    final sunday = monday.add(const Duration(days: 6));

    // 2️⃣ Aggregate kcal per day
    final Map<String, double> totals = {};
    for (var item in rawData) {
      final date = DateTime.parse(item['created_at']).toLocal();
      if (date.isBefore(monday) || date.isAfter(sunday)) continue;

      final key = DateFormat('E').format(date); // Mon, Tue, etc.
      totals[key] = (totals[key] ?? 0) + (item['kcal'] ?? 0).toDouble();
    }

    // 3️⃣ Fixed order Monday → Sunday
    const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    weeklyCalories = weekOrder.map((day) {
      return {'day': day, 'kcal': totals[day] ?? 0};
    }).toList();
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
              : Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15), // subtle all-around shadow
                            blurRadius: 7,
                            offset: const Offset(0, 2), // vertical shadow
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: SevenDayLineChart(weeklyData: weeklyCalories),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                   child: ListView.builder(
                    itemCount: foodHistory.length,
                    itemBuilder: (context, index) {
                      final food = foodHistory[index];
                          // 👇 Add the chart above the first record only
                        return FutureBuilder<String?>(
                          future: _getSignedImageUrl(food['image_url']),
                          builder: (context, snapshot) {
                            final signedUrl = food['signed_url'] ?? snapshot.data;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromRGBO(0, 0, 0, 0.13),
                                    blurRadius: 6,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: Card(
                                color: Colors.white,
                                elevation: 0,
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: image on left, name (below image) and kcal on right-ish
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Image + label stacked
                                          Column(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  width: 54,
                                                  height: 54,
                                                  color: Colors.white,
                                                  child: signedUrl != null
                                                      ? FadeInImage.assetNetwork(
                                                          placeholder: 'assets/white.png',
                                                          image: signedUrl,
                                                          fit: BoxFit.cover,
                                                          fadeInDuration: const Duration(milliseconds: 200),
                                                          fadeOutDuration: const Duration(milliseconds: 200),
                                                          imageErrorBuilder: (_, __, ___) =>
                                                              Image.asset('assets/white.png', fit: BoxFit.cover),
                                                        )
                                                      : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                                                ),
                                              ),                                        
                                            ],
                                          ),

                                          const SizedBox(width: 12),
                                          // kcal and spacer to push macros row below
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _titleCaseLabel(food['label'] ?? 'Unknown Meal'),
                                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                        food['created_at'] != null
                                                          ? DateFormat('hh:mm a').format(DateTime.parse(food['created_at']).toLocal())
                                                          : '',
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 14),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${food['kcal'] ?? 0} kcal',
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                                    ),
                                                  ],
                                                ),                                
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Row 2: macros (Protein / Carbs / Fat) spaced evenly
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _MacroColumn(label: 'Protein', value: '${food['protein_g'] ?? 0}', color: Colors.indigoAccent),
                                          _MacroColumn(label: 'Carbs', value: '${food['carbs_g'] ?? 0}', color: Colors.redAccent),
                                          _MacroColumn(label: 'Fat', value: '${food['fat_g'] ?? 0}', color:Colors.orangeAccent),
                                          _MacroColumn(label: 'Fiber', value: '${food['fiber_g'] ?? 0}', color: Colors.greenAccent),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                        },
                      ),
                    ),
                  ],
                ),
      
                bottomNavigationBar: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  clipBehavior: Clip.none,
                  child: Container(
                    height: 85,
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

