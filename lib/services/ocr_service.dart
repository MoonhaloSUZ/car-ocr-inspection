import 'dart:io';
import 'dart:math' show min, max;
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum OcrFieldType {
  plateNo,
  modemNo,
  sensorId,
  cameraId,
  general,
}

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  // ── 이미지 전처리 변형 생성 (isolate) ─────────────────────

  static List<Uint8List> _generateVariants(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];
    final gray = img.grayscale(decoded);

    final v1 = img.adjustColor(gray, contrast: 1.3, brightness: 1.05);
    final v2 = img.convolution(
      img.gaussianBlur(gray, radius: 1),
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
    );
    final scale = (3000.0 / decoded.width).clamp(0.0, 2.0);
    final upscaled = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
    final v3 = img.adjustColor(img.grayscale(upscaled), contrast: 1.3);

    return [
      img.encodeJpg(v1, quality: 95),
      img.encodeJpg(v2, quality: 95),
      img.encodeJpg(v3, quality: 90),
    ];
  }

  Future<List<String>> _prepareVariantPaths(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final variants = await compute(_generateVariants, bytes);
    final dir = await getTemporaryDirectory();
    return Future.wait(variants.map((v) async {
      final path = '${dir.path}/${const Uuid().v4()}_ocr.jpg';
      await File(path).writeAsBytes(v);
      return path;
    }));
  }

  // ── 공개 API ───────────────────────────────────────────────

  Future<OcrResult> recognize(String imagePath, OcrFieldType fieldType) async {
    if (fieldType == OcrFieldType.plateNo) {
      return _recognizePlate(imagePath);
    }
    final variantPaths = await _prepareVariantPaths(imagePath);
    for (final path in [...variantPaths, imagePath]) {
      final result = await _runOcr(path, fieldType);
      if (result.hasResult) return result;
    }
    return _runOcr(imagePath, fieldType);
  }

  // ── 차량번호 인식 흐름 ─────────────────────────────────────
  //
  // 1단계: 원본 + 전처리 3종으로 전체 이미지 OCR
  // 2단계: 실패 시 숫자 bounding box 기반 번호판 크롭 후 재시도
  // ★ 매칭 성공 후: 한글 위치만 정밀 크롭+확대하여 한글 재인식 (사↔고 오인식 교정)

  Future<OcrResult> _recognizePlate(String imagePath) async {
    final variantPaths = await _prepareVariantPaths(imagePath);

    OcrResult? fallbackResult;
    for (final path in [imagePath, ...variantPaths]) {
      final result = await _runPlateOcr(path);
      if (result.hasResult) {
        return _withRefinedKorean(result, path);
      }
      fallbackResult ??= result;
    }

    final croppedPath = await _detectAndCropPlate(imagePath);
    if (croppedPath != null) {
      final croppedVariants = await _prepareVariantPaths(croppedPath);
      for (final path in [croppedPath, ...croppedVariants]) {
        final result = await _runPlateOcr(path);
        if (result.hasResult) {
          return _withRefinedKorean(result, path);
        }
      }
    }

    return fallbackResult ?? await _runPlateOcr(imagePath);
  }

  // ── 한글 자 정밀 재인식 ────────────────────────────────────

  // 1차 매칭에서 얻은 판번호의 한글 위치를 bounding box로 찾아
  // 해당 영역만 300px 높이로 확대 후 한글만 재인식
  // 예: "96고2268" → 한글 위치 크롭 → 재인식 → "사" → "96사2268"
  Future<OcrResult> _withRefinedKorean(
      OcrResult result, String imagePath) async {
    final plate = result.bestMatch!;

    final korRec = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final recognized =
          await korRec.processImage(InputImage.fromFilePath(imagePath));

      final korBbox = _findKoreanCharBbox(recognized, plate);
      if (korBbox == null) return result;

      final charPath = await _cropToKoreanChar(imagePath, korBbox);
      if (charPath == null) return result;

      final charRec = TextRecognizer(script: TextRecognitionScript.korean);
      try {
        final charResult =
            await charRec.processImage(InputImage.fromFilePath(charPath));
        final refined = RegExp(r'[가-힣]')
            .firstMatch(charResult.text.replaceAll(RegExp(r'\s'), ''))
            ?.group(0);

        if (refined != null) {
          final refinedPlate =
              plate.replaceFirst(RegExp(r'[가-힣]'), refined);
          return OcrResult(
            rawText: result.rawText,
            allLines: result.allLines,
            elements: result.elements,
            bestMatch: refinedPlate,
            fieldType: result.fieldType,
          );
        }
      } finally {
        charRec.close();
      }
    } catch (_) {
    } finally {
      korRec.close();
    }

    return result;
  }

  // OCR 결과에서 한글 원소의 bounding box 탐색
  // 1순위: 한글 단독 element
  // 2순위: 복합 element 내 한글 위치를 문자 폭으로 계산
  Rect? _findKoreanCharBbox(RecognizedText recognized, String plate) {
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          if (RegExp(r'^[가-힣]$').hasMatch(element.text.trim())) {
            return element.boundingBox;
          }
        }
      }
    }
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final text = element.text.replaceAll(RegExp(r'\s'), '');
          final m = RegExp(r'[가-힣]').firstMatch(text);
          if (m != null) {
            final charWidth = element.boundingBox.width / text.length;
            return Rect.fromLTWH(
              element.boundingBox.left + charWidth * m.start,
              element.boundingBox.top,
              charWidth,
              element.boundingBox.height,
            );
          }
        }
      }
    }
    return null;
  }

  Future<String?> _cropToKoreanChar(String imagePath, Rect bbox) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final result = await compute(
          _cropCharIsolate,
          _CropParams(
            bytes: bytes,
            left: bbox.left,
            top: bbox.top,
            right: bbox.right,
            bottom: bbox.bottom,
          ));
      if (result == null) return null;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${const Uuid().v4()}_kor_char.jpg';
      await File(path).writeAsBytes(result);
      return path;
    } catch (_) {
      return null;
    }
  }

  // 한글 한 글자만 크롭: 상하좌우 50% 패딩 + 300px 높이로 확대 + 대비 강화
  static Uint8List? _cropCharIsolate(_CropParams p) {
    final decoded = img.decodeImage(p.bytes);
    if (decoded == null) return null;

    final bboxW = p.right - p.left;
    final bboxH = p.bottom - p.top;
    final padX = (bboxW * 0.5).toInt();
    final padY = (bboxH * 0.5).toInt();

    final x = max(0, (p.left - padX).toInt());
    final y = max(0, (p.top - padY).toInt());
    final right = min(decoded.width, (p.right + padX).toInt());
    final bottom = min(decoded.height, (p.bottom + padY).toInt());
    final w = right - x;
    final h = bottom - y;
    if (w <= 0 || h <= 0) return null;

    var cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

    if (cropped.height < 300) {
      final upScale = 300.0 / cropped.height;
      cropped = img.copyResize(
        cropped,
        width: (cropped.width * upScale).round(),
        height: 300,
        interpolation: img.Interpolation.cubic,
      );
    }

    final enhanced =
        img.adjustColor(img.grayscale(cropped), contrast: 1.5, brightness: 1.05);
    return img.encodeJpg(enhanced, quality: 100);
  }

  // ── 번호판 영역 감지 + 크롭 ───────────────────────────────

  Future<String?> _detectAndCropPlate(String imagePath) async {
    final korRec = TextRecognizer(script: TextRecognitionScript.korean);
    final latRec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final results = await Future.wait([
        korRec.processImage(inputImage),
        latRec.processImage(inputImage),
      ]);

      Rect? plateBbox;
      final digitPattern = RegExp(r'\d{4}');
      for (final recognized in results) {
        for (final block in recognized.blocks) {
          if (digitPattern
              .hasMatch(block.text.replaceAll(RegExp(r'\s'), ''))) {
            plateBbox = plateBbox == null
                ? block.boundingBox
                : plateBbox.expandToInclude(block.boundingBox);
          }
        }
      }

      if (plateBbox == null || plateBbox.isEmpty) return null;
      return _cropAndUpscale(imagePath, plateBbox);
    } catch (_) {
      return null;
    } finally {
      korRec.close();
      latRec.close();
    }
  }

  Future<String?> _cropAndUpscale(String imagePath, Rect bbox) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final result = await compute(
          _cropAndUpscaleIsolate,
          _CropParams(
            bytes: bytes,
            left: bbox.left,
            top: bbox.top,
            right: bbox.right,
            bottom: bbox.bottom,
          ));
      if (result == null) return null;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${const Uuid().v4()}_plate_crop.jpg';
      await File(path).writeAsBytes(result);
      return path;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _cropAndUpscaleIsolate(_CropParams p) {
    final decoded = img.decodeImage(p.bytes);
    if (decoded == null) return null;

    final bboxW = p.right - p.left;
    final bboxH = p.bottom - p.top;

    final x = max(0, (p.left - bboxW * 2.0).toInt());
    final y = max(0, (p.top - bboxH * 0.8).toInt());
    final right = min(decoded.width, (p.right + bboxW * 0.5).toInt());
    final bottom = min(decoded.height, (p.bottom + bboxH * 0.8).toInt());
    final w = right - x;
    final h = bottom - y;
    if (w <= 0 || h <= 0) return null;

    var cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

    if (cropped.width < 800) {
      final upScale = 800.0 / cropped.width;
      cropped = img.copyResize(
        cropped,
        width: 800,
        height: (cropped.height * upScale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    final enhanced =
        img.adjustColor(img.grayscale(cropped), contrast: 1.4);
    return img.encodeJpg(enhanced, quality: 100);
  }

  // ── 한국어 + 라틴 두 패스 병렬 인식 ─────────────────────

  Future<OcrResult> _runPlateOcr(String imagePath) async {
    final korRec = TextRecognizer(script: TextRecognitionScript.korean);
    final latRec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final results = await Future.wait([
        korRec.processImage(inputImage),
        latRec.processImage(inputImage),
      ]);
      final kor = results[0];
      final lat = results[1];

      final korLines = _toLines(kor);
      final korElems = _toElements(kor);
      final latLines = _toLines(lat);
      final latElems = _toElements(lat);

      final best = _findPlateNo([...korLines, ...latLines])
          ?? _findPlateNo([...korElems, ...latElems])
          ?? _findPlateNo([kor.text])
          ?? _findPlateNo([lat.text]);

      return OcrResult(
        rawText: kor.text,
        allLines: korLines,
        elements: korElems,
        bestMatch: best,
        fieldType: OcrFieldType.plateNo,
      );
    } catch (e) {
      return OcrResult(
        rawText: '',
        allLines: [],
        bestMatch: null,
        fieldType: OcrFieldType.plateNo,
        error: e.toString(),
      );
    } finally {
      korRec.close();
      latRec.close();
    }
  }

  // ── 일반 타입 인식 ────────────────────────────────────────

  Future<OcrResult> _runOcr(String imagePath, OcrFieldType fieldType) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final lines = _toLines(recognized);
      final elements = _toElements(recognized);
      final best = _extractBest(recognized.text, lines, elements, fieldType);
      return OcrResult(
        rawText: recognized.text,
        allLines: lines,
        elements: elements,
        bestMatch: best,
        fieldType: fieldType,
      );
    } catch (e) {
      return OcrResult(
        rawText: '',
        allLines: [],
        bestMatch: null,
        fieldType: fieldType,
        error: e.toString(),
      );
    } finally {
      recognizer.close();
    }
  }

  // ── 텍스트 추출 헬퍼 ──────────────────────────────────────

  List<String> _toLines(RecognizedText r) => r.blocks
      .expand((b) => b.lines)
      .map((l) => l.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  List<String> _toElements(RecognizedText r) => r.blocks
      .expand((b) => b.lines)
      .expand((l) => l.elements)
      .map((e) => e.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  // ── 패턴 매칭 ─────────────────────────────────────────────

  String? _extractBest(
    String fullText,
    List<String> lines,
    List<String> elements,
    OcrFieldType type,
  ) {
    switch (type) {
      case OcrFieldType.plateNo:
        return _findPlateNo(lines)
            ?? _findPlateNo(elements)
            ?? _findPlateNo([fullText]);
      case OcrFieldType.modemNo:
        return _findModemNo(lines) ?? _findModemNo([fullText]);
      case OcrFieldType.sensorId:
        return _findSensorId(lines) ?? _findSensorId([fullText]);
      case OcrFieldType.cameraId:
        return _findCameraId(lines) ?? _findCameraId([fullText]);
      case OcrFieldType.general:
        return lines.isNotEmpty ? lines.first : null;
    }
  }

  static const Map<String, String> _plateOcrFix = {
    '1': '고',
    '7': '고',
    '6': '고',
    '0': '오',
    '8': '바',
  };

  static final _wsPattern = RegExp(r'\s+');
  static final _exactPlatePattern = RegExp(r'\d{2,3}[가-힣]\d{4}');

  String? _findPlateNo(List<String> lines) {
    for (final line in lines) {
      final clean = line.replaceAll(_wsPattern, '');
      final m = _exactPlatePattern.firstMatch(clean);
      if (m != null) return m.group(0);
    }
    final joined = lines.join('').replaceAll(_wsPattern, '');
    final mj = _exactPlatePattern.firstMatch(joined);
    if (mj != null) return mj.group(0);
    return _fuzzyPlateNo(lines);
  }

  String? _fuzzyPlateNo(List<String> lines) {
    final candidates = [
      ...lines.map((l) => l.replaceAll(_wsPattern, '')),
      lines.join('').replaceAll(_wsPattern, ''),
    ];
    for (final clean in candidates) {
      final m8 =
          RegExp(r'(?<!\d)(\d{3})(\d)(\d{4})(?!\d)').firstMatch(clean);
      if (m8 != null) {
        final fixed = _plateOcrFix[m8.group(2)!];
        if (fixed != null) return '${m8.group(1)}$fixed${m8.group(3)}';
      }
      final m7 =
          RegExp(r'(?<!\d)(\d{2})(\d)(\d{4})(?!\d)').firstMatch(clean);
      if (m7 != null) {
        final fixed = _plateOcrFix[m7.group(2)!];
        if (fixed != null) return '${m7.group(1)}$fixed${m7.group(3)}';
      }
    }
    return null;
  }

  String? _findModemNo(List<String> lines) {
    final pattern = RegExp(r'0\d{2}[-–]\d{3,4}[-–]\d{4}');
    for (final line in lines) {
      final m = pattern.firstMatch(line);
      if (m != null) return m.group(0)!.replaceAll('–', '-');
    }
    return null;
  }

  String? _findSensorId(List<String> lines) {
    final patterns = [
      RegExp(r'T[23]-STR\d{2}-\d{3}', caseSensitive: false),
      RegExp(r'T[23]-\d{2}-\d{3}', caseSensitive: false),
      RegExp(r'WS\d{4}-\d{3}', caseSensitive: false),
      RegExp(r'RLS\d{2}-\d{3}', caseSensitive: false),
      RegExp(r'RLS-\d{3}', caseSensitive: false),
    ];
    for (final line in lines) {
      final clean = line.replaceAll(' ', '');
      for (final p in patterns) {
        final m = p.firstMatch(clean);
        if (m != null) return m.group(0)!.toUpperCase();
      }
    }
    return null;
  }

  String? _findCameraId(List<String> lines) {
    final pattern =
        RegExp(r'CA(?:LS)?[A-Z0-9]*[-]\d{3}', caseSensitive: false);
    for (final line in lines) {
      final clean = line.replaceAll(' ', '');
      final m = pattern.firstMatch(clean);
      if (m != null) return m.group(0)!.toUpperCase();
    }
    return null;
  }

  bool get isAvailable => Platform.isAndroid || Platform.isIOS;
}

class _CropParams {
  final Uint8List bytes;
  final double left, top, right, bottom;
  const _CropParams({
    required this.bytes,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

class OcrResult {
  final String rawText;
  final List<String> allLines;
  final List<String> elements;
  final String? bestMatch;
  final OcrFieldType fieldType;
  final String? error;

  const OcrResult({
    required this.rawText,
    required this.allLines,
    this.elements = const [],
    required this.bestMatch,
    required this.fieldType,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasResult => bestMatch != null && bestMatch!.isNotEmpty;
}
