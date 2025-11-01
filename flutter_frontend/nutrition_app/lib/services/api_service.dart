// lib/services/api_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

Future<Map<String, dynamic>> uploadImageToServer({
  required Uint8List imageBytes,
  required String serverBaseUrl, // e.g. "http://192.168.1.100:8000"
  double? multiplier,
  int? grams,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final uri = Uri.parse('$serverBaseUrl/predict');
  final request = http.MultipartRequest('POST', uri);

  // ask server for JSON response
  request.headers['Accept'] = 'application/json';

  // guess mime type and build filename
  final contentType = lookupMimeType('image.jpg', headerBytes: imageBytes) ?? 'image/jpeg';
  final parts = contentType.split('/');
  final mediaType = MediaType(parts[0], parts.length > 1 ? parts[1] : 'jpeg');
  final filename = 'capture_${DateTime.now().millisecondsSinceEpoch}${_extensionFromMime(parts.length>1?parts[1]:null)}';

  // attach file
  request.files.add(http.MultipartFile.fromBytes(
    'file',
    imageBytes,
    filename: filename,
    contentType: mediaType,
  ));

  // optional scaling fields
  if (grams != null) {
    request.fields['grams'] = grams.toString();
  } else if (multiplier != null) {
    request.fields['mult'] = multiplier.toString();
  }

  final streamed = await request.send().timeout(timeout);
  final resp = await http.Response.fromStream(streamed).timeout(timeout);

  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    final jsonBody = json.decode(resp.body) as Map<String, dynamic>;
    return jsonBody;
  } else {
    throw Exception('Server error ${resp.statusCode}: ${resp.body}');
  }
}

String _extensionFromMime(String? subtype) {
  if (subtype == null) return '.jpg';
  switch (subtype) {
    case 'jpeg':
    case 'jpg':
      return '.jpg';
    case 'png':
      return '.png';
    case 'gif':
      return '.gif';
    case 'webp':
      return '.webp';
    default:
      return '.jpg';
  }
}
