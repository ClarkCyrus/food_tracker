import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../widgets/camera_widget.dart'; // Add this import

class CameraPage extends StatefulWidget {
  final CameraDescription camera;
  const CameraPage({required this.camera, super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  late final CameraService _cameraService;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = CameraService(widget.camera);
    _init();
  }

  Future<void> _init() async {
    await _cameraService.start();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraWidget(
        camera: widget.camera,
        onCapture: (bytes) {
          Navigator.pop<Uint8List>(context, bytes);
        },
      ),
    );
  }
}
