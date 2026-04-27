import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class PhotoPickerWidget extends StatelessWidget {
  final List<String> photoPaths;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;
  final int maxPhotos;

  const PhotoPickerWidget({
    super.key,
    required this.photoPaths,
    required this.onChanged,
    this.enabled = true,
    this.maxPhotos = 10,
  });

  Future<void> _addPhoto(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (file == null) return;

    // Copy to app documents dir
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create(recursive: true);

    final ext = p.extension(file.path);
    final fileName = '${const Uuid().v4()}$ext';
    final dest = '${photoDir.path}/$fileName';
    await File(file.path).copy(dest);

    // DB에는 파일명만 저장 (절대경로는 재시작 시 변경됨)
    onChanged([...photoPaths, fileName]);
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    final updated = [...photoPaths];
    updated.removeAt(index);
    onChanged(updated);
  }

  void _viewPhoto(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(imagePath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...photoPaths.asMap().entries.map((e) {
          final index = e.key;
          final path = e.value;
          return GestureDetector(
            onTap: () => _viewPhoto(context, path),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                if (enabled)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (enabled && photoPaths.length < maxPhotos)
          GestureDetector(
            onTap: () => _showAddOptions(context),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_a_photo,
                  color: Colors.grey.shade500, size: 24),
            ),
          ),
      ],
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final String imagePath;
  const _PhotoViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('사진 보기'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
