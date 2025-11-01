import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import 'framing_overlay.dart';

class CameraWidget extends StatefulWidget {
  final CameraDescription camera;
  final void Function(Uint8List bytes) onCapture;
  const CameraWidget({required this.camera, required this.onCapture, super.key});

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  late final CameraService _cameraService;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService(widget.camera);
    _init();
  }

  Future<void> _init() async {
    await _cameraService.start();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _cameraService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        CameraPreview(_cameraService.controller),
        const FramingOverlay(
          aspectRatio: 1.0, // or whatever aspect ratio you want
          borderColor: Colors.white,
          borderWidth: 3.0,
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: FloatingActionButton.small(
            onPressed: () async {
              final bytes = await _cameraService.takePictureBytes();
              widget.onCapture(bytes);
            },
            child: const Icon(Icons.camera),
          ),
        ),
      ],
    );
  }
}
