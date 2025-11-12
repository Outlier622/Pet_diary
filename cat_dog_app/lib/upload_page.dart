import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class UploadPage extends StatefulWidget {
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _picker = ImagePicker();
  File? _image;
  bool _busy = false;

  final TextEditingController _serverCtrl =
      TextEditingController(text: 'http://192.168.137.1:5000');
  final TextEditingController _apiKeyCtrl =
      TextEditingController(text: '');

  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 95); 
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => _image = file);

    await _classifyImage(file);
  }

  Future<void> _classifyImage(File imageFile) async {
    final base = _serverCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/classify');

    final req = http.MultipartRequest('POST', uri);
    req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final key = _apiKeyCtrl.text.trim();
    if (key.isNotEmpty) {
      req.headers['X-API-Key'] = key;
    }

    try {
      setState(() => _busy = true);
      final resp = await req.send();

      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 200) {
        final result = jsonDecode(body) as Map<String, dynamic>;
        _showResultDialog(result);
      } else {
        _showErrorDialog(
          'Upload failed: HTTP ${resp.statusCode}\n$body',
        );
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Classification Result'),
        content: Text(_formatResult(result)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  String _formatResult(Map<String, dynamic> result) =>
      result.entries.map((e) => '${e.key}: ${e.value}').join('\n');

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePreview = _image != null
        ? Image.file(_image!, height: 220, fit: BoxFit.cover)
        : Container(
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('No Image Selected'),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Photo')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                TextField(
                  controller: _serverCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server Base URL',
                    hintText: 'http://<ip>:5000',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'X-API-Key (optional)',
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagePreview,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : () => _pickAndUpload(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capture & Upload'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAndUpload(ImageSource.gallery),
                        icon: const Icon(Icons.photo),
                        label: const Text('Pick & Upload'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
