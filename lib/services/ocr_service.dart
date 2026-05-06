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

  // ── 이미지 전처리 변형 (isolate) ──────────────────────────

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

  // ── 공개 API ──────────────────────────────────────────────

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

  // ── 차량번호 인식 흐름 ────────────────────────────────────

  Future<OcrResult> _recognizePlate(String imagePath) async {
    final variantPaths = await _prepareVariantPaths(imagePath);
    OcrResult? fallbackResult;

    for (final path in [imagePath, ...variantPaths]) {
      final inter = await _runPlateOcr(path);
      if (inter.result.hasResult) {
        return _withRefinedKorean(inter, path);
      }
      fallbackResult ??= inter.result;
    }

    // 번호판 영역 크롭 후 재시도
    final croppedPath = await _detectAndCropPlate(imagePath);
    if (croppedPath != null) {
      final croppedVariants = await _prepareVariantPaths(croppedPath);
      for (final path in [croppedPath, ...croppedVariants]) {
        final inter = await _runPlateOcr(path);
        if (inter.result.hasResult) {
          return _withRefinedKorean(inter, path);
        }
      }
    }

    return fallbackResult ?? (await _runPlateOcr(imagePath)).result;
  }

  // ── 한글 자 정밀 재인식 (핵심 로직) ─────────────────────
  //
  // 문제: ML Kit이 "허" → "0"(ㅎ 원형) + "고"(나머지)로 단편화
  //   → 앞 숫자 영역에 "0"이 섞여 "02" → "020"으로 오집계 → 포맷 오판
  //
  // 해결:
  //   1) 뒷번호(4자리) bbox에서 cw = width / 4 추정
  //   2) front element 기준선을 rear.left - cw*0.8로 좁혀 한글 파편 제외
  //   3) 실제 front digit 자릿수로 포맷 결정 (2→2+1+4, ≥3→3+1+4)
  //   4) 한글 구간 = [rear.left - 1.6*cw, rear.left + 0.15*cw] (포맷 무관)
  //   5) 400px 확대 + 강화 contrast로 한글 재인식 → 앞·뒤 숫자와 합성

  Future<OcrResult> _withRefinedKorean(
      _PlateOcrInter inter, String imagePath) async {
    final result = inter.result;
    final korRaw = inter.korRecognized;
    final latRaw = inter.latRecognized;
    if (korRaw == null || latRaw == null) return result;

    try {
      // 모든 element 수집 + x좌표 정렬
      final elems = <_TextElem>[];
      for (final rec in [korRaw, latRaw]) {
        for (final block in rec.blocks) {
          for (final line in block.lines) {
            for (final elem in line.elements) {
              final t = elem.text.replaceAll(RegExp(r'\s'), '');
              if (t.isNotEmpty) elems.add(_TextElem(t, elem.boundingBox));
            }
          }
        }
      }
      elems.sort((a, b) => a.bbox.left.compareTo(b.bbox.left));

      // 뒷번호(4자리) 탐색: 오른쪽부터 첫 번째 \d{4} element
      _TextElem? rear;
      for (final e in elems.reversed) {
        if (RegExp(r'\d{4}').hasMatch(e.text)) {
          rear = e;
          break;
        }
      }
      if (rear == null) return result;

      // 글자 1개 폭 추정
      final cw = rear.bbox.width / 4.0;
      if (cw <= 0) return result;

      // front element: 한글 구간(≈rear.left-cw ~ rear.left) 제외하고 좌측만
      // "허"가 "0"으로 파편화돼도 rear.left - cw*0.8 기준선 안쪽에 있으므로 배제
      final frontCutoff = rear.bbox.left - cw * 0.8;
      final frontElems = elems
          .where((e) =>
              e.bbox.right < frontCutoff &&
              RegExp(r'\d').hasMatch(e.text))
          .toList();
      if (frontElems.isEmpty) return result;

      // 한글 구간: rear.left 기준으로 역산 (포맷 무관하게 항상 직전 1글자)
      final allTops = [...frontElems.map((e) => e.bbox.top), rear.bbox.top];
      final allBottoms = [...frontElems.map((e) => e.bbox.bottom), rear.bbox.bottom];
      final charTop = allTops.reduce(min) - cw * 0.4;
      final charBottom = allBottoms.reduce(max) + cw * 0.4;

      // 왼쪽을 1.6*cw까지 넓혀 파편화된 한글 조각도 포함
      final korRegion = Rect.fromLTRB(
        rear.bbox.left - cw * 1.6,
        charTop,
        rear.bbox.left + cw * 0.15,
        charBottom,
      );

      if (korRegion.width <= 0 || korRegion.height <= 0) return result;

      // 한글 구간 크롭 + 400px 확대
      final charPath = await _cropToKoreanChar(imagePath, korRegion);
      if (charPath == null) return result;

      // 한글 OCR: 원본 + 전처리 variant 전부 시도
      String? refined;
      final korVariants = await _prepareVariantPaths(charPath);
      for (final path in [charPath, ...korVariants]) {
        final rec = TextRecognizer(script: TextRecognitionScript.korean);
        try {
          final r = await rec.processImage(InputImage.fromFilePath(path));
          final kor = RegExp(r'[가-힣]')
              .firstMatch(r.text.replaceAll(RegExp(r'\s'), ''))
              ?.group(0);
          if (kor != null) {
            refined = kor;
            break;
          }
        } finally {
          rec.close();
        }
      }

      if (refined == null) return result;

      // 앞 숫자: 한글 영역 밖 element만 남겼으므로 실제 자릿수 = 포맷 결정
      final frontDigitsAll = frontElems
          .map((e) => e.text.replaceAll(RegExp(r'[^\d]'), ''))
          .join();
      if (frontDigitsAll.length < 2) return result;
      final nFront = frontDigitsAll.length >= 3 ? 3 : 2;
      final frontStr = frontDigitsAll.substring(0, nFront);

      // 뒷 숫자: rear element에서 마지막 4자리
      final rearDigits = rear.text.replaceAll(RegExp(r'[^\d]'), '');
      if (rearDigits.length < 4) return result;
      final rearStr = rearDigits.substring(rearDigits.length - 4);

      final refinedPlate = '$frontStr$refined$rearStr';
      if (!_exactPlatePattern.hasMatch(refinedPlate)) return result;

      return OcrResult(
        rawText: result.rawText,
        allLines: result.allLines,
        elements: result.elements,
        bestMatch: refinedPlate,
        fieldType: result.fieldType,
      );
    } catch (_) {
      return result;
    }
  }

  // ── 한글 구간 크롭 + 확대 ────────────────────────────────

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
              bottom: bbox.bottom));
      if (result == null) return null;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${const Uuid().v4()}_kor_char.jpg';
      await File(path).writeAsBytes(result);
      return path;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _cropCharIsolate(_CropParams p) {
    final decoded = img.decodeImage(p.bytes);
    if (decoded == null) return null;
    final bboxW = p.right - p.left;
    final bboxH = p.bottom - p.top;
    // 호출자가 이미 넉넉한 region을 전달하므로 padding 최소화
    final padX = (bboxW * 0.08).toInt();
    final padY = (bboxH * 0.08).toInt();
    final x = max(0, (p.left - padX).toInt());
    final y = max(0, (p.top - padY).toInt());
    final right = min(decoded.width, (p.right + padX).toInt());
    final bottom = min(decoded.height, (p.bottom + padY).toInt());
    final w = right - x;
    final h = bottom - y;
    if (w <= 0 || h <= 0) return null;
    var cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    if (cropped.height < 400) {
      final s = 400.0 / cropped.height;
      cropped = img.copyResize(
        cropped,
        width: (cropped.width * s).round(),
        height: 400,
        interpolation: img.Interpolation.cubic,
      );
    }
    return img.encodeJpg(
        img.adjustColor(img.grayscale(cropped), contrast: 1.8, brightness: 1.1),
        quality: 100);
  }

  // ── 번호판 영역 감지 + 크롭 ──────────────────────────────

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
      for (final rec in results) {
        for (final block in rec.blocks) {
          if (digitPattern.hasMatch(block.text.replaceAll(RegExp(r'\s'), ''))) {
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
              bottom: bbox.bottom));
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
      final s = 800.0 / cropped.width;
      cropped = img.copyResize(
        cropped,
        width: 800,
        height: (cropped.height * s).round(),
        interpolation: img.Interpolation.cubic,
      );
    }
    return img.encodeJpg(
        img.adjustColor(img.grayscale(cropped), contrast: 1.4), quality: 100);
  }

  // ── 한국어 + 라틴 두 패스 병렬 인식 ─────────────────────

  Future<_PlateOcrInter> _runPlateOcr(String imagePath) async {
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
      final result = OcrResult(
        rawText: kor.text,
        allLines: korLines,
        elements: korElems,
        bestMatch: best,
        fieldType: OcrFieldType.plateNo,
      );
      return _PlateOcrInter(result, kor, lat);
    } catch (e) {
      return _PlateOcrInter(
        OcrResult(
            rawText: '',
            allLines: [],
            bestMatch: null,
            fieldType: OcrFieldType.plateNo,
            error: e.toString()),
        null,
        null,
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
          fieldType: fieldType);
    } catch (e) {
      return OcrResult(
          rawText: '',
          allLines: [],
          bestMatch: null,
          fieldType: fieldType,
          error: e.toString());
    } finally {
      recognizer.close();
    }
  }

  // ── 텍스트 추출 ───────────────────────────────────────────

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

  String? _extractBest(String fullText, List<String> lines,
      List<String> elements, OcrFieldType type) {
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

// ── 내부 헬퍼 클래스 ──────────────────────────────────────

class _PlateOcrInter {
  final OcrResult result;
  final RecognizedText? korRecognized;
  final RecognizedText? latRecognized;
  const _PlateOcrInter(this.result, this.korRecognized, this.latRecognized);
}

class _TextElem {
  final String text;
  final Rect bbox;
  const _TextElem(this.text, this.bbox);
}

class _CropParams {
  final Uint8List bytes;
  final double left, top, right, bottom;
  const _CropParams(
      {required this.bytes,
      required this.left,
      required this.top,
      required this.right,
      required this.bottom});
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
