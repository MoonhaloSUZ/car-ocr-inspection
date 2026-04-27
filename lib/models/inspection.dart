class Inspection {
  final String id;
  String location;
  String inspector;
  String? overallNote;
  final DateTime createdAt;
  List<InspectionResult> results;
  List<InspectionPhoto> photos;

  Inspection({
    required this.id,
    required this.location,
    required this.inspector,
    this.overallNote,
    required this.createdAt,
    this.results = const [],
    this.photos = const [],
  });

  factory Inspection.fromMap(Map<String, dynamic> map) => Inspection(
        id: map['id'] as String,
        location: map['location'] as String,
        inspector: map['inspector'] as String? ?? '',
        overallNote: map['overall_note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'location': location,
        'inspector': inspector,
        'overall_note': overallNote,
        'created_at': createdAt.toIso8601String(),
      };

  int get totalItems => results.length;
  int get yCount => results.where((r) => r.result == 'Y').length;
  int get nCount => results.where((r) => r.result == 'N').length;
  int get naCount => results.where((r) => r.result == 'NA').length;
  int get unchecked =>
      results.where((r) => r.result == null || r.result!.isEmpty).length;

  double get completionRate =>
      totalItems > 0 ? (totalItems - unchecked) / totalItems : 0.0;
}

class InspectionResult {
  final String id;
  final String inspectionId;
  final String itemId;
  String? result; // 'Y', 'N', 'NA', or null
  String? note;

  InspectionResult({
    required this.id,
    required this.inspectionId,
    required this.itemId,
    this.result,
    this.note,
  });

  factory InspectionResult.fromMap(Map<String, dynamic> map) =>
      InspectionResult(
        id: map['id'] as String,
        inspectionId: map['inspection_id'] as String,
        itemId: map['item_id'] as String,
        result: map['result'] as String?,
        note: map['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'inspection_id': inspectionId,
        'item_id': itemId,
        'result': result,
        'note': note,
      };
}

class InspectionPhoto {
  final String id;
  final String inspectionId;
  final String? itemId; // null = overall photo
  String photoPath; // mutable - 런타임에 절대경로로 교체됨

  InspectionPhoto({
    required this.id,
    required this.inspectionId,
    this.itemId,
    required this.photoPath,
  });

  factory InspectionPhoto.fromMap(Map<String, dynamic> map) => InspectionPhoto(
        id: map['id'] as String,
        inspectionId: map['inspection_id'] as String,
        itemId: map['item_id'] as String?,
        photoPath: map['photo_path'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'inspection_id': inspectionId,
        'item_id': itemId,
        'photo_path': photoPath,
      };
}
