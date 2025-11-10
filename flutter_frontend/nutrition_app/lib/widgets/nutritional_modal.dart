import 'package:flutter/material.dart';

  Future<Map<String, dynamic>?> showEditNutritionModal({
    required BuildContext context,
    Map<String, dynamic>? initial,
    String? imageUrl,
    double imageHeight = 300,   // visible image height used in Home
    double overlap = 16,        // how much the image should overflow under the rounded sheet=
  })
  
    {
    final media = MediaQuery.of(context);
    final totalHeight = media.size.height;
    final sheetTop = (imageHeight - overlap).clamp(0.0, totalHeight);

    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return SizedBox(
          height: totalHeight,
          width: double.infinity,
          child: Stack(
            children: [
              // Top image from URL
              if (imageUrl != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: imageHeight,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      // 👇 Prevents layout jump or error flicker
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        // If it's loaded instantly (from cache), show immediately
                        if (wasSynchronouslyLoaded) return child;

                        // While loading, just keep showing a plain background placeholder
                        return Container(
                          color: Colors.white, // or a light gray
                          child: frame != null
                              ? child // once first frame arrives, swap instantly
                              : Container(color: Colors.white),
                        );
                      },
                      // 👇 Avoids the “red X” or crash UI on load error
                      errorBuilder: (context, error, stackTrace) => 
                          Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                // The rounded sheet positioned to overlap the image by `overlap`
                Positioned(
                  left: 0,
                  right: 0,
                  top: sheetTop,
                  bottom: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: SafeArea(
                        top: false,
                        child: Theme(
                          data: Theme.of(ctx).copyWith(
                            textSelectionTheme: const TextSelectionThemeData(
                              cursorColor: Color.fromARGB(255, 175, 250, 214),
                              selectionColor: Color.fromARGB(255, 175, 250, 214),
                              selectionHandleColor: Color.fromARGB(255, 3, 209, 110),
                            ),
                            inputDecorationTheme: InputDecorationTheme(
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(color: Color.fromARGB(255, 0, 166, 86)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: const Color.fromARGB(255, 143, 143, 143)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          child: _EditNutritionContent(initial: initial),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

/* Keep the rest of the content the same as your _EditNutritionContent implementation.
   Example _EditNutritionContent below — reuse your existing implementation. */

  class _EditNutritionContent extends StatefulWidget {
    final Map<String, dynamic>? initial;
    const _EditNutritionContent({Key? key, this.initial}) : super(key: key);

    @override
    State<_EditNutritionContent> createState() => _EditNutritionContentState();
  }

  class _EditNutritionContentState extends State<_EditNutritionContent> {
    late final TextEditingController labelCtrl;
    late final TextEditingController kcalCtrl;
    late final TextEditingController proteinCtrl;
    late final TextEditingController fatCtrl;
    late final TextEditingController carbsCtrl;
    late final TextEditingController fiberCtrl;

    final labelFocus = FocusNode();
    final kcalFocus = FocusNode();
    final proteinFocus = FocusNode();
    final fatFocus = FocusNode();
    final carbsFocus = FocusNode();
    final fiberFocus = FocusNode();

    late double baseKcal;
    late double baseProtein;
    late double baseFat;
    late double baseCarbs;
    late double baseFiber;
    late int servings;

    final edits = <String, bool>{
      'label': false,
      'kcal': false,
      'protein': false,
      'fat': false,
      'carbs': false,
      'fiber': false,
    };

    @override
    void initState() {
      super.initState();

      servings = widget.initial?['servings'] ?? 1;
      baseKcal = (widget.initial?['kcal'] ?? 0) / servings;
      baseProtein = (widget.initial?['protein_g'] ?? 0) / servings;
      baseFat = (widget.initial?['fat_g'] ?? 0) / servings;
      baseCarbs = (widget.initial?['carbs_g'] ?? 0) / servings;
      baseFiber = (widget.initial?['fiber_g'] ?? 0) / servings;

      kcalCtrl = TextEditingController(text: (baseKcal * servings).toStringAsFixed(2));
      proteinCtrl = TextEditingController(text: (baseProtein * servings).toStringAsFixed(2));
      fatCtrl = TextEditingController(text: (baseFat * servings).toStringAsFixed(2));
      carbsCtrl = TextEditingController(text: (baseCarbs * servings).toStringAsFixed(2));
      fiberCtrl = TextEditingController(text: (baseFiber * servings).toStringAsFixed(2));
      labelCtrl = TextEditingController(
        text: widget.initial?['label'] != null 
            ? _titleCaseLabel(widget.initial!['label'].toString()) 
            : ''
      );
    }

    String normalize(String v) {
      final s = v.trim();
      if (s.isEmpty || s == '-') return '-';
      return s;
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
    void dispose() {
      labelCtrl.dispose();
      kcalCtrl.dispose();
      proteinCtrl.dispose();
      fatCtrl.dispose();
      carbsCtrl.dispose();
      fiberCtrl.dispose();
      labelFocus.dispose();
      kcalFocus.dispose();
      proteinFocus.dispose();
      fatFocus.dispose();
      carbsFocus.dispose();
      fiberFocus.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: edits['label'] == true
                            ? TextField(
                                controller: labelCtrl,
                                focusNode: labelFocus,
                                autofocus: true,
                                textAlign: TextAlign.start,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                onSubmitted: (_) => setState(() => edits['label'] = false),
                              )
                            : Text(
                                _titleCaseLabel(
                                  labelCtrl.text.isNotEmpty
                                      ? labelCtrl.text
                                      : _titleCaseLabel(widget.initial?['label']?.toString() ?? 'Unknown'),
                                ),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      IconButton(
                        icon: Icon(
                          edits['label'] == true ? Icons.check : Icons.edit,
                          size: 20
                        ),
                        onPressed: () {
                          setState(() {
                            edits['label'] = !(edits['label'] ?? false);
                          });
                        },
                      ),

                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Calories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(id: 'kcal', label: 'kcal', controller: kcalCtrl, focusNode: kcalFocus,),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _servingsField(
                      id: 'servings',
                      value: servings,
                      onChanged: (v) {
                        // update servings
                        servings = v;

                        // update the TextEditingControllers for nutrients
                        kcalCtrl.text = (baseKcal * servings).toStringAsFixed(2);
                        proteinCtrl.text = (baseProtein * servings).toStringAsFixed(2);
                        fatCtrl.text = (baseFat * servings).toStringAsFixed(2);
                        carbsCtrl.text = (baseCarbs * servings).toStringAsFixed(2);
                        fiberCtrl.text = (baseFiber * servings).toStringAsFixed(2);

                        // trigger rebuild to update the servings text
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
                const SizedBox(height: 20),
                const Text('Macronutrients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _field(id: 'carbs', label: 'Carbs (g)', controller: carbsCtrl, focusNode: carbsFocus)),
                    const SizedBox(width: 28),
                    Expanded(child: _field(id: 'protein', label: 'Protein (g)', controller: proteinCtrl, focusNode: proteinFocus)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _field(id: 'fat', label: 'Fat (g)', controller: fatCtrl, focusNode: fatFocus)),
                    const SizedBox(width: 28),
                    Expanded(child: _field(id: 'fiber', label: 'Fiber (g)', controller: fiberCtrl, focusNode: fiberFocus)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // put this after your Expanded(scrollable content) and optional Divider
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal:0, vertical: 10),
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), 
                                  side: const BorderSide(
                                    color: Color.fromARGB(255, 0, 0, 0), // border color
                                    width: 1, // optional: border width
                                  ),
                                ),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                              ),
                              child: const Text('Cancel',
                                style: TextStyle(
                                    color: Color.fromARGB(255, 247, 25, 25),
                                    fontSize: 16,
                                  ),
                                ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final result = <String, dynamic>{
                                  'label': normalize(labelCtrl.text),
                                  'kcal': normalize(kcalCtrl.text),
                                  'protein_g': normalize(proteinCtrl.text),
                                  'fat_g': normalize(fatCtrl.text),
                                  'carbs_g': normalize(carbsCtrl.text),
                                  'fiber_g': normalize(fiberCtrl.text),
                                  'servings': servings,
                                };
                                Navigator.of(context).pop(result);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), 
                                  side: const BorderSide(
                                    color: Color.fromARGB(255, 0, 0, 0), // border color
                                    width: 1, // optional: border width
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 67, 219, 6),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    }

    Widget _field({
      required String id,
      required String label,
      required TextEditingController controller,
      required FocusNode focusNode,
    }) {
      final isEditing = edits[id] ?? false;
      return TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: !isEditing,
        enableInteractiveSelection: isEditing,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onTap: () {
          if (!isEditing) FocusScope.of(context).unfocus();
        },
        decoration: InputDecoration(
          labelText: label,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color.fromARGB(255, 0, 0, 0)), // border color when not focused
          ),
          filled: true,
          fillColor: isEditing ? Colors.grey[100] : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          /*
          suffixIcon: IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit, size: 20),
            onPressed: () => setState(() => edits[id] = !(edits[id] ?? false)),
          ),
          */
        ),
      );
    }
  }

 Widget _servingsField({
  required String id,
  required int value,
  required void Function(int) onChanged,
}) {
  return InputDecorator(
    decoration: InputDecoration(
      labelText: 'Servings',
        isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 14),
          splashRadius: 20,
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 14),
          splashRadius: 20,
          onPressed: () => onChanged(value + 1),
        ),
      ],
    ),
  );
}
