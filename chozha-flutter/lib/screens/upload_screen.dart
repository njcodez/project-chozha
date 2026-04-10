// lib/screens/upload_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_snackbar.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  File? _image;
  bool _uploading = false;
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 90);
    if (xfile == null) return;
    setState(() => _image = File(xfile.path));
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    if (_image == null) return;
    final username = ref.read(usernameProvider);
    if (username == null) return;

    final api = ref.read(apiServiceProvider).valueOrNull;
    if (api == null) {
      showErrorSnackbar(context, 'API not ready');
      return;
    }

    setState(() => _uploading = true);
    try {
      final jobId = await api.createJob(
        image: _image!,
        username: username,
        isPublic: true,
      );
      if (!mounted) return;
      context.pushReplacement('/job/$jobId');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final username = ref.watch(usernameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Upload')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image preview / picker
              Expanded(
                child: GestureDetector(
                  onTap: _showPickerSheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: cs.outlineVariant, width: 1.5),
                    ),
                    child: _image == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 56, color: cs.primary),
                              const SizedBox(height: 12),
                              Text('Tap to select an image',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_image!, fit: BoxFit.cover),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton.filled(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: _showPickerSheet,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Username display
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(username ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('uploading as',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    (_image == null || _uploading) ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_rounded),
                label: Text(_uploading ? 'Uploading…' : 'Process Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
