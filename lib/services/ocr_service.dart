import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum OcrFieldType {
  plateNo, // 차량번호 - 한국 번호판 패턴
  modemNo, // 모뎀번호 - 전화번호 패턴 012-xxxx-xxxx
  sensorId, // 센서ID - 영숫자 코드
  cameraId, // 카메라ID - CA로 시작하는 코드
  general, // 일반 텍스트
}

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  // ── 이미지 전처리 ──────────────────────────────────────────

  // compute() isolate에서 실행: 그레이스케일 + 대비 강화
  static Uint8List? _preprocessBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final gray = img.grayscale(decoded);
    final enhanced = img.adjustColor(gray, contrast: 1.3, brightness: 1.05);
    return img.encodeJpg(enhanced, quality: 95);
  }

  Future<String?> _preprocessImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final processed = await compute(_preprocessBytes, bytes);
      if (processed == null) return null;
      final dir = await getTemporaryDirectory();
      final dest = '${dir.path}/${const Uuid().v4()}_ocr.jpg';
      await File(dest).writeAsBytes(processed);
      return dest;
    } catch (_) {
      return null;
    }
  }

  // ── 공개 API ───────────────────────────────────────────────

  Future<OcrResult> recognize(String imagePath, OcrFieldType fieldType) async {
    // 전처리 이미지(그레이스케일+대비 강화) 먼저 시도, 실패 시 원본으로 폴백
    final preprocessed = await _preprocessImage(imagePath);
    for (final path in [if (preprocessed != null) preprocessed, imagePath]) {
      final result = await _runOcr(path, fieldType);
      if (result.hasResult) return result;
    }
    return _runOcr(imagePath, fieldType);
  }

  // ── 인식 실행 ──────────────────────────────────────────────

  Future<OcrResult> _runOcr(String imagePath, OcrFieldType fieldType) async {
    if (fieldType == OcrFieldType.plateNo) {
      return _runPlateOcr(imagePath);
    }
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

  // 차량번호: 한국어 + 라틴 두 패스 병렬 인식 후 병합
  // - 한국어 패스: 한글 문자 인식에 강함
  // - 라틴 패스: 숫자/영문 인식 정확도가 높음
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

      // 한국어 결과 우선, 라틴 결과 보조
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

  // 번호판 한글 위치에서 숫자로 오인식되는 경우 보정 맵
  static const Map<String, String> _plateOcrFix = {
    '1': '고', // 고 → 1 (가장 빈번한 오인식)
    '7': '고', // 고 → 7 (ㄱ 형태 혼동)
    '0': '오', // 오 → 0 (원형 혼동)
    '6': '고', // 고 → 6 (형태 혼동)
  };

  static final _wsPattern = RegExp(r'\s+');

  // 한국 차량번호 패턴: 숫자2-3 + 한글1 + 숫자4  (예: 86누0773, 157고4895)
  String? _findPlateNo(List<String> lines) {
    final exactPattern = RegExp(r'\d{2,3}[가-힣]\d{4}');

    // 1단계: 각 라인 개별 검색 (모든 공백·뉴라인 제거)
    for (final line in lines) {
      final clean = line.replaceAll(_wsPattern, '');
      final m = exactPattern.firstMatch(clean);
      if (m != null) return m.group(0);
    }

    // 2단계: 모든 라인 합쳐서 검색
    // 한글이 별도 ML Kit 블록/라인으로 인식된 경우 복원
    // 예: ["154", "러", "7070"] → "154러7070"
    final joined = lines.join('').replaceAll(_wsPattern, '');
    final mj = exactPattern.firstMatch(joined);
    if (mj != null) return mj.group(0);

    // 3단계: 한글이 숫자로 오인식된 경우 퍼지 보정
    return _fuzzyPlateNo(lines);
  }

  String? _fuzzyPlateNo(List<String> lines) {
    final candidates = [
      ...lines.map((l) => l.replaceAll(_wsPattern, '')),
      lines.join('').replaceAll(_wsPattern, ''),
    ];

    for (final clean in candidates) {
      // 3자리 앞번호 형식: NNN + 한글(오인식) + NNNN = 8자리
      final m8 =
          RegExp(r'(?<!\d)(\d{3})(\d)(\d{4})(?!\d)').firstMatch(clean);
      if (m8 != null) {
        final fixed = _plateOcrFix[m8.group(2)!];
        if (fixed != null) return '${m8.group(1)}$fixed${m8.group(3)}';
      }

      // 2자리 앞번호 형식: NN + 한글(오인식) + NNNN = 7자리
      final m7 =
          RegExp(r'(?<!\d)(\d{2})(\d)(\d{4})(?!\d)').firstMatch(clean);
      if (m7 != null) {
        final fixed = _plateOcrFix[m7.group(2)!];
        if (fixed != null) return '${m7.group(1)}$fixed${m7.group(3)}';
      }
    }
    return null;
  }

  // 모뎀번호 패턴: 010/012-xxxx-xxxx
  String? _findModemNo(List<String> lines) {
    final pattern = RegExp(r'0\d{2}[-–]\d{3,4}[-–]\d{4}');
    for (final line in lines) {
      final m = pattern.firstMatch(line);
      if (m != null) return m.group(0)!.replaceAll('–', '-');
    }
    return null;
  }

  // 센서ID 패턴: RLS, WS, T2-STR, T3-STR 등
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

  // 카메라ID 패턴: CA + 숫자 (예: CA21-008, CALS-091)
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
