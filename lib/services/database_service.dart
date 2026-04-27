import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/checklist_template.dart';
import '../models/inspection.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;
  final _uuid = const Uuid();

  // ─── 사진 경로 헬퍼 ────────────────────────────────────────────────
  // DB에는 파일명만 저장하고, 실제 경로는 런타임에 조합
  static String? _photoBasePath;

  static Future<String> getPhotoBasePath() async {
    if (_photoBasePath != null) return _photoBasePath!;
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create(recursive: true);
    _photoBasePath = photoDir.path;
    return _photoBasePath!;
  }

  /// 파일명 → 전체 절대경로 변환
  static Future<String> resolvePhotoPath(String fileNameOrPath) async {
    // 이미 절대경로인 경우 (구버전 데이터 호환)
    if (fileNameOrPath.startsWith('/') || fileNameOrPath.contains(':\\')) {
      return fileNameOrPath;
    }
    final base = await getPhotoBasePath();
    return '$base/$fileNameOrPath';
  }

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'field_inspection.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE inspections (
        id TEXT PRIMARY KEY,
        location TEXT NOT NULL,
        inspector TEXT NOT NULL DEFAULT '',
        overall_note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE inspection_results (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        result TEXT,
        note TEXT,
        FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE inspection_photos (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        item_id TEXT,
        photo_path TEXT NOT NULL,
        FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE
      )
    ''');

    await _seedDefaultTemplate(db);
  }

  Future<void> _seedDefaultTemplate(Database db) async {
    final defaultData = [
      {
        'id': 'cat_safety',
        'title': '안전관리',
        'order': 1,
        'items': [
          {'id': 'item_s1', 'title': '안전모 착용 여부'},
          {'id': 'item_s2', 'title': '안전화 착용 여부'},
          {'id': 'item_s3', 'title': '안전벨트 착용 여부'},
          {'id': 'item_s4', 'title': '안전 표지판 설치 여부'},
          {'id': 'item_s5', 'title': '작업 구역 안전선 설치'},
        ],
      },
      {
        'id': 'cat_facility',
        'title': '설비 점검',
        'order': 2,
        'items': [
          {'id': 'item_f1', 'title': '소화기 비치 및 상태'},
          {'id': 'item_f2', 'title': '전기 배선 상태'},
          {'id': 'item_f3', 'title': '비상구 확보 여부'},
          {'id': 'item_f4', 'title': '기계·설비 작동 상태'},
          {'id': 'item_f5', 'title': '누전 차단기 정상 작동'},
        ],
      },
      {
        'id': 'cat_env',
        'title': '환경 관리',
        'order': 3,
        'items': [
          {'id': 'item_e1', 'title': '폐기물 분리·처리 상태'},
          {'id': 'item_e2', 'title': '작업장 청결 유지'},
          {'id': 'item_e3', 'title': '유해물질 보관 상태'},
          {'id': 'item_e4', 'title': '환기 시설 작동 여부'},
        ],
      },
      {
        'id': 'cat_doc',
        'title': '서류 확인',
        'order': 4,
        'items': [
          {'id': 'item_d1', 'title': '안전교육 이수 여부'},
          {'id': 'item_d2', 'title': '작업 허가서 비치'},
          {'id': 'item_d3', 'title': '점검 일지 작성 여부'},
        ],
      },
    ];

    for (int ci = 0; ci < defaultData.length; ci++) {
      final cat = defaultData[ci];
      await db.insert('categories', {
        'id': cat['id'],
        'title': cat['title'],
        'sort_order': cat['order'],
      });
      final itemList = cat['items'] as List<Map<String, String>>;
      for (int ii = 0; ii < itemList.length; ii++) {
        await db.insert('items', {
          'id': itemList[ii]['id'],
          'category_id': cat['id'],
          'title': itemList[ii]['title'],
          'sort_order': ii + 1,
        });
      }
    }
  }

  // ─── Template CRUD ──────────────────────────────────────────────────

  Future<List<ChecklistCategory>> getTemplate() async {
    final db = await database;
    final catMaps = await db.query('categories', orderBy: 'sort_order ASC');
    final itemMaps = await db.query('items', orderBy: 'sort_order ASC');

    final categories =
        catMaps.map((m) => ChecklistCategory.fromMap(m)).toList();
    for (final cat in categories) {
      cat.items = itemMaps
          .where((m) => m['category_id'] == cat.id)
          .map((m) => ChecklistItem.fromMap(m))
          .toList();
    }
    return categories;
  }

  Future<String> addCategory(String title, int sortOrder) async {
    final db = await database;
    final id = _uuid.v4();
    await db.insert('categories', {
      'id': id,
      'title': title,
      'sort_order': sortOrder,
    });
    return id;
  }

  Future<void> updateCategory(String id, String title) async {
    final db = await database;
    await db.update(
      'categories',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderCategories(List<ChecklistCategory> categories) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < categories.length; i++) {
      batch.update(
        'categories',
        {'sort_order': i + 1},
        where: 'id = ?',
        whereArgs: [categories[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<String> addItem(String categoryId, String title, int sortOrder) async {
    final db = await database;
    final id = _uuid.v4();
    await db.insert('items', {
      'id': id,
      'category_id': categoryId,
      'title': title,
      'sort_order': sortOrder,
    });
    return id;
  }

  Future<void> updateItem(String id, String title) async {
    final db = await database;
    await db.update(
      'items',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderItems(List<ChecklistItem> items) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(
        'items',
        {'sort_order': i + 1},
        where: 'id = ?',
        whereArgs: [items[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ─── Inspection CRUD ─────────────────────────────────────────────────

  Future<List<Inspection>> getInspections({
    String? locationFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final db = await database;

    String where = '';
    final List<dynamic> whereArgs = [];

    if (locationFilter != null && locationFilter.isNotEmpty) {
      where += 'location LIKE ?';
      whereArgs.add('%$locationFilter%');
    }
    if (dateFrom != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'created_at >= ?';
      whereArgs.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'created_at <= ?';
      whereArgs.add(dateTo.add(const Duration(days: 1)).toIso8601String());
    }

    final maps = await db.query(
      'inspections',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    final inspections = maps.map((m) => Inspection.fromMap(m)).toList();

    for (final insp in inspections) {
      final resultMaps = await db.query(
        'inspection_results',
        where: 'inspection_id = ?',
        whereArgs: [insp.id],
      );
      insp.results =
          resultMaps.map((m) => InspectionResult.fromMap(m)).toList();

      final photoMaps = await db.query(
        'inspection_photos',
        where: 'inspection_id = ?',
        whereArgs: [insp.id],
      );
      final photoBasePath = await getPhotoBasePath();
      insp.photos = photoMaps.map((m) {
        final photo = InspectionPhoto.fromMap(m);
        // 전체경로/파일명 모두 → 파일명만 추출 후 현재 base path로 재조합
        // (절대경로는 앱 재시작 시 UUID가 바뀌어 무효화되므로 항상 재조합)
        final fileName = basename(photo.photoPath);
        photo.photoPath = '$photoBasePath/$fileName';
        return photo;
      }).toList();
    }

    return inspections;
  }

  Future<Inspection?> getInspection(String id) async {
    final db = await database;
    final maps =
        await db.query('inspections', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final insp = Inspection.fromMap(maps.first);

    final resultMaps = await db.query(
      'inspection_results',
      where: 'inspection_id = ?',
      whereArgs: [id],
    );
    insp.results = resultMaps.map((m) => InspectionResult.fromMap(m)).toList();

    final photoMaps = await db.query(
      'inspection_photos',
      where: 'inspection_id = ?',
      whereArgs: [id],
    );
    final photoBasePath = await getPhotoBasePath();
    insp.photos = photoMaps.map((m) {
      final photo = InspectionPhoto.fromMap(m);
      // 전체경로/파일명 모두 → 파일명만 추출 후 현재 base path로 재조합
      // (절대경로는 앱 재시작 시 UUID가 바뀌어 무효화되므로 항상 재조합)
      final fileName = basename(photo.photoPath);
      photo.photoPath = '$photoBasePath/$fileName';
      return photo;
    }).toList();

    return insp;
  }

  Future<String> saveInspection({
    required String location,
    required String inspector,
    String? overallNote,
    required DateTime date,
    required Map<String, String?> results,
    required Map<String, String> notes,
    required Map<String, List<String>> photos,
    String? existingId,
  }) async {
    final db = await database;
    final id = existingId ?? _uuid.v4();

    // CASCADE가 SQLite 기본 비활성이므로 자식 테이블 먼저 명시적으로 삭제
    await db.delete('inspection_photos',
        where: 'inspection_id = ?', whereArgs: [id]);
    await db.delete('inspection_results',
        where: 'inspection_id = ?', whereArgs: [id]);
    await db.delete('inspections', where: 'id = ?', whereArgs: [id]);

    await db.insert('inspections', {
      'id': id,
      'location': location,
      'inspector': inspector,
      'overall_note': overallNote,
      'created_at': date.toIso8601String(),
    });

    for (final entry in results.entries) {
      await db.insert('inspection_results', {
        'id': _uuid.v4(),
        'inspection_id': id,
        'item_id': entry.key,
        'result': entry.value,
        'note': notes[entry.key],
      });
    }

    for (final entry in photos.entries) {
      for (final path in entry.value) {
        // 절대경로에서 파일명만 추출해 저장 (재시작 시 경로 변경 대응)
        final fileName = basename(path);
        await db.insert('inspection_photos', {
          'id': _uuid.v4(),
          'inspection_id': id,
          'item_id': entry.key == '__overall__' ? null : entry.key,
          'photo_path': fileName,
        });
      }
    }

    return id;
  }

  Future<void> deleteInspection(String id) async {
    final db = await database;
    await db.delete('inspection_photos',
        where: 'inspection_id = ?', whereArgs: [id]);
    await db.delete('inspection_results',
        where: 'inspection_id = ?', whereArgs: [id]);
    await db.delete('inspections', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getDistinctLocations() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT location FROM inspections ORDER BY location ASC',
    );
    return maps.map((m) => m['location'] as String).toList();
  }
}
