import 'dart:typed_data';
import 'package:camera/camera.dart';

class CameraService {
  final CameraDescription camera;
  late CameraController _controller;
  bool _initialized = false;

  CameraService(this.camera);

  Future<void> start() async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller.initialize();
    _initialized = true;
  }

  CameraController get controller {
    if (!_initialized) throw Exception('Camera not initialized');
    return _controller;
  }

  Future<XFile> takePicture() async {
    if (!_initialized) throw Exception('Camera not initialized');
    return await _controller.takePicture();
  }

  Future<Uint8List> takePictureBytes() async {
    final file = await takePicture();
    return await file.readAsBytes();
  }

  Future<void> stop() async {
    if (_initialized) {
      await _controller.dispose();
      _initialized = false;
    }
  }
}
