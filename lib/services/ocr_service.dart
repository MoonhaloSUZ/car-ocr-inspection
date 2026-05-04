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

  // ── 이미지 전처리 (isolate) ────────────────────────────────

  // 3가지 전처리 변형을 한 번에 생성
  // V1: 그레이스케일 + 대비 강화
  // V2: 그레이스케일 + 선명화 (unsharp mask)
  // V3: 2배 확대 + 그레이스케일 + 대비 강화 (번호판이 작게 찍혔을 때)
  static List<Uint8List> _generateVariants(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];

    final gray = img.grayscale(decoded);

    final v1 = img.adjustColor(gray, contrast: 1.3, brightness: 1.05);

    final v2 = img.convolution(
      img.gaussianBlur(gray, radius: 1),
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
    );

    // 최대 2배, width 3000px 이하로 비율 유지 확대
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
    final paths = <String>[];
    for (final v in variants) {
      final path = '${dir.path}/${const Uuid().v4()}_ocr.jpg';
      await File(path).writeAsBytes(v);
      paths.add(path);
    }
    return paths;
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

  // ── 차량번호 전용 ──────────────────────────────────────────

  // 원본 → V1(대비) → V2(선명화) → V3(확대+대비) 순으로 시도, 첫 매칭 반환
  Future<OcrResult> _recognizePlate(String imagePath) async {
    final variantPaths = await _prepareVariantPaths(imagePath);
    for (final path in [imagePath, ...variantPaths]) {
      final result = await _runPlateOcr(path);
      if (result.hasResult) return result;
    }
    // 모든 시도 실패 시 원본 결과 반환 (후보 다이얼로그용 rawText 포함)
    return _runPlateOcr(imagePath);
  }

  // 한국어 + 라틴 두 패스 병렬 인식 후 병합
  // - 한국어 패스: 한글 문자 인식에 강함
  // - 라틴 패스: 숫자/영문 정확도 높음, 보조 역할
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

      // 한국어 결과 우선 탐색, 라틴 보조
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

  // 번호판 한글 위치 오인식 보정 맵 (한글 위치에만 적용)
  static const Map<String, String> _plateOcrFix = {
    '1': '고', // 고 → 1 (수직선 혼동)
    '7': '고', // 고 → 7 (ㄱ 형태 혼동)
    '6': '고', // 고 → 6 (형태 혼동)
    '0': '오', // 오 → 0 (원형 혼동)
    '8': '바', // 바 → 8 (ㅂ 형태 혼동)
  };

  static final _wsPattern = RegExp(r'\s+');
  static final _exactPlatePattern = RegExp(r'\d{2,3}[가-힣]\d{4}');

  // 한국 차량번호 패턴: 숫자2-3 + 한글1 + 숫자4
  String? _findPlateNo(List<String> lines) {
    // 1단계: 각 라인 정확 매칭 (모든 공백·뉴라인 제거)
    for (final line in lines) {
      final clean = line.replaceAll(_wsPattern, '');
      final m = _exactPlatePattern.firstMatch(clean);
      if (m != null) return m.group(0);
    }

    // 2단계: 전체 라인 join (한글이 별도 블록으로 인식된 경우 복원)
    final joined = lines.join('').replaceAll(_wsPattern, '');
    final mj = _exactPlatePattern.firstMatch(joined);
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
      // 3자리 앞번호: NNN + 한글(오인식) + NNNN = 8자리
      final m8 =
          RegExp(r'(?<!\d)(\d{3})(\d)(\d{4})(?!\d)').firstMatch(clean);
      if (m8 != null) {
        final fixed = _plateOcrFix[m8.group(2)!];
        if (fixed != null) return '${m8.group(1)}$fixed${m8.group(3)}';
      }

      // 2자리 앞번호: NN + 한글(오인식) + NNNN = 7자리
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
