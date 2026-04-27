import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

  /// 이미지에서 텍스트를 인식하고 필드 타입에 맞는 후보를 반환
  Future<OcrResult> recognize(String imagePath, OcrFieldType fieldType) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);

      final allText = recognized.text;
      final lines = recognized.blocks
          .expand((b) => b.lines)
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final best = _extractBest(allText, lines, fieldType);

      return OcrResult(
        rawText: allText,
        allLines: lines,
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

  String? _extractBest(String fullText, List<String> lines, OcrFieldType type) {
    switch (type) {
      case OcrFieldType.plateNo:
        return _findPlateNo(lines) ?? _findPlateNo([fullText]);

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

  // 한국 차량번호 패턴: 숫자2 + 한글1 + 숫자4  (예: 86누0773)
  String? _findPlateNo(List<String> lines) {
    final pattern = RegExp(r'\d{2,3}[가-힣]\d{4}');
    for (final line in lines) {
      final clean = line.replaceAll(' ', '');
      final m = pattern.firstMatch(clean);
      if (m != null) return m.group(0);
    }
    return null;
  }

  // 모뎀번호 패턴: 010/012-xxxx-xxxx
  String? _findModemNo(List<String> lines) {
    final pattern = RegExp(r'0\d{2}[-–]\d{3,4}[-–]\d{4}');
    for (final line in lines) {
      final m = pattern.firstMatch(line);
      if (m != null) {
        return m.group(0)!.replaceAll('–', '-');
      }
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
    final pattern = RegExp(r'CA(?:LS)?[A-Z0-9]*[-]\d{3}', caseSensitive: false);
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
  final String? bestMatch;
  final OcrFieldType fieldType;
  final String? error;

  const OcrResult({
    required this.rawText,
    required this.allLines,
    required this.bestMatch,
    required this.fieldType,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasResult => bestMatch != null && bestMatch!.isNotEmpty;
}
