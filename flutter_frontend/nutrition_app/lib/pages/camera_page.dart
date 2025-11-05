import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({Key? key}) : super(key: key);

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _isCameraReady = true);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final XFile file = await _controller!.takePicture();
    final bytes = await file.readAsBytes();

    // Return the photo bytes to the caller
    Navigator.of(context).pop(bytes);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _takePhoto,
                child: const Icon(Icons.camera_alt, color: Color.fromARGB(255, 3, 209, 110)),
              ),
            ),
          ),
        ],
      )
    );
  }
}
