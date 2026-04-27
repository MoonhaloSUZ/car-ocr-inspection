import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../utils/theme.dart';

class PhotoSlotWidget extends StatelessWidget {
  final String slotKey;
  final String label;
  final String? photoPath; // null = 아직 미촬영
  final ValueChanged<String> onPhotoSaved; // 새 사진 fullPath 전달
  final VoidCallback? onRemove;
  final bool enabled;

  const PhotoSlotWidget({
    super.key,
    required this.slotKey,
    required this.label,
    required this.photoPath,
    required this.onPhotoSaved,
    this.onRemove,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1920);
    if (file == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create(recursive: true);

    final ext = p.extension(file.path);
    final dest = '${photoDir.path}/${const Uuid().v4()}$ext';
    await File(file.path).copy(dest);
    onPhotoSaved(dest);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('카메라'),
            onTap: () {
              Navigator.pop(ctx);
              _pick(context, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('갤러리'),
            onTap: () {
              Navigator.pop(ctx);
              _pick(context, ImageSource.gallery);
            },
          ),
          if (photoPath != null && onRemove != null)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                onRemove!();
              },
            ),
        ]),
      ),
    );
  }

  void _viewFull(BuildContext context) {
    if (photoPath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenPhoto(path: photoPath!, label: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => hasPhoto
              ? _viewFull(context)
              : (enabled ? _showOptions(context) : null),
          onLongPress: enabled ? () => _showOptions(context) : null,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: hasPhoto ? null : Colors.grey.shade100,
                border: Border.all(
                  color: hasPhoto
                      ? AppTheme.primaryColor.withOpacity(0.4)
                      : Colors.grey.shade300,
                  width: hasPhoto ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(photoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ),
                          if (enabled)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _showOptions(context),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.edit,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _placeholder(showAdd: enabled),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: hasPhoto ? AppTheme.primaryColor : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _placeholder({bool showAdd = false}) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showAdd ? Icons.add_a_photo : Icons.photo_camera_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 6),
          Text(
            showAdd ? '탭하여 사진 추가' : '사진 없음',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      );
}

class _FullScreenPhoto extends StatelessWidget {
  final String path;
  final String label;
  const _FullScreenPhoto({required this.path, required this.label});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(label),
        ),
        body: InteractiveViewer(
          child: Center(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white, size: 64),
            ),
          ),
        ),
      );
}
