// lib/test.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const TestApp());

class TestApp extends StatelessWidget {
  const TestApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: UploadPage());
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final TextEditingController _urlController =
      TextEditingController(text: 'http://10.0.2.2:8000/predict');
  final ImagePicker _picker = ImagePicker();
  XFile? _picked;
  Uint8List? _pickedBytes;
  String _result = '';
  bool _loading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _picked = picked;
          _pickedBytes = bytes;
          _result = '';
        });
      } else {
        setState(() {
          _picked = picked;
          _pickedBytes = null;
          _result = '';
        });
      }
    } catch (e) {
      setState(() => _result = 'Pick error: $e');
    }
  }

  Future<void> _upload() async {
    if (_picked == null) {
      setState(() => _result = 'No image selected');
      return;
    }
    final urlText = _urlController.text.trim();
    if (urlText.isEmpty) {
      setState(() => _result = 'Enter backend URL ending with /predict');
      return;
    }
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(urlText);
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final bytes = _pickedBytes ?? await _picked!.readAsBytes();
        final multipart = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: _picked!.name,
        );
        request.files.add(multipart);
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', _picked!.path));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      setState(() {
        if (resp.statusCode == 200) {
          try {
            final decoded = json.decode(resp.body);
            _result = const JsonEncoder.withIndent('  ').convert(decoded);
          } catch (_) {
            _result = '200 OK but failed to parse JSON: ${resp.body}';
          }
        } else {
          _result = 'Error ${resp.statusCode}: ${resp.body}';
        }
      });
    } catch (e) {
      setState(() => _result = 'Upload exception: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildPreview() {
    if (_picked == null) return const SizedBox.shrink();
    if (kIsWeb && _pickedBytes != null) {
      return Image.memory(_pickedBytes!, height: 220);
    } else {
      return Image.file(File(_picked!.path), height: 220);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Upload')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Backend URL (full)',
              hintText: 'http://10.0.2.2:8000/predict',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _buildPreview(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick Image'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _upload,
                icon: _loading ? const SizedBox.shrink() : const Icon(Icons.upload_file),
                label: Text(_loading ? 'Uploading...' : 'Upload'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _result.isEmpty ? 'Result will appear here' : _result,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
