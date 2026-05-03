import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../services/ocr_service.dart';
import '../utils/theme.dart';

class OcrInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final OcrFieldType fieldType;
  final String? hint;
  final bool required;
  final ValueChanged<String>? onChanged;

  const OcrInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.fieldType,
    this.hint,
    this.required = false,
    this.onChanged,
  });

  @override
  State<OcrInputField> createState() => _OcrInputFieldState();
}

class _OcrInputFieldState extends State<OcrInputField> {
  bool _scanning = false;

  Future<void> _scanWithCamera(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 100, // JPEG 압축 손실 최소화
      maxWidth: 2500,    // 더 높은 해상도로 문자 디테일 확보
    );
    if (file == null || !mounted) return;

    setState(() => _scanning = true);

    try {
      // 임시 저장
      final dir = await getTemporaryDirectory();
      final ext = p.extension(file.path);
      final dest = '${dir.path}/${const Uuid().v4()}$ext';
      await File(file.path).copy(dest);

      final result = await OcrService().recognize(dest, widget.fieldType);

      if (!mounted) return;

      if (result.hasError) {
        _showSnack('인식 오류: ${result.error}');
        return;
      }

      if (!result.hasResult && result.allLines.isEmpty) {
        _showSnack('텍스트를 인식하지 못했습니다');
        return;
      }

      // 후보 선택 다이얼로그
      await _showCandidateDialog(result);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _showCandidateDialog(OcrResult result) async {
    final candidates = <String>[];
    if (result.bestMatch != null) candidates.add(result.bestMatch!);
    for (final line in result.allLines) {
      if (line != result.bestMatch && line.length <= 40) {
        candidates.add(line);
      }
    }
    if (candidates.isEmpty) {
      _showSnack('인식된 텍스트가 없습니다');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.text_fields, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('인식된 텍스트 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            Text('${widget.label}에 입력할 값을 선택하세요',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Divider(),
            ...candidates.asMap().entries.map((e) {
              final isFirst = e.key == 0 && result.bestMatch != null;
              return ListTile(
                dense: true,
                leading: isFirst
                    ? const Icon(Icons.star,
                        color: AppTheme.primaryColor, size: 16)
                    : const SizedBox(width: 16),
                title: Text(e.value, style: const TextStyle(fontSize: 14)),
                subtitle: isFirst
                    ? const Text('추천',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.primaryColor))
                    : null,
                onTap: () {
                  widget.controller.text = e.value;
                  widget.onChanged?.call(e.value);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('직접 입력하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('카메라로 촬영'),
            onTap: () {
              Navigator.pop(ctx);
              _scanWithCamera(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('갤러리에서 선택'),
            onTap: () {
              Navigator.pop(ctx);
              _scanWithCamera(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            widget.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (widget.required)
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hint ?? widget.label,
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDDE3DD))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDDE3DD))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 1.5)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _scanning
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Tooltip(
                  message: '사진으로 자동입력',
                  child: InkWell(
                    onTap: _showSourcePicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.document_scanner,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                  ),
                ),
        ]),
      ],
    );
  }
}
