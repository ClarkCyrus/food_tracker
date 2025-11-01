import 'package:flutter/material.dart';

class FramingOverlay extends StatelessWidget {
  final double aspectRatio;
  final Color borderColor;
  final double borderWidth;

  const FramingOverlay({
    this.aspectRatio = 1.0,
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
