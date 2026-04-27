import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/vehicle.dart';
import '../models/inspection_record.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'livestock_v2.db');
    return openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        serial_no INTEGER NOT NULL DEFAULT 0,
        plate_no TEXT NOT NULL,
        owner TEXT NOT NULL DEFAULT '',
        vehicle_type TEXT NOT NULL DEFAULT '',
        axle_count TEXT NOT NULL DEFAULT '',
        gross_weight TEXT NOT NULL DEFAULT '',
        max_load TEXT NOT NULL DEFAULT '',
        modem_no TEXT NOT NULL DEFAULT '',
        sensor_id TEXT NOT NULL DEFAULT '',
        camera_id TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE inspections (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        mgmt_no TEXT NOT NULL DEFAULT '',
        inspection_date TEXT NOT NULL DEFAULT '',
        driver_org TEXT NOT NULL DEFAULT '',
        driver_name TEXT NOT NULL DEFAULT '',
        driver_contact TEXT NOT NULL DEFAULT '',
        plate_no TEXT NOT NULL DEFAULT '',
        vehicle_type TEXT NOT NULL DEFAULT '',
        gross_weight TEXT NOT NULL DEFAULT '',
        axle_count TEXT NOT NULL DEFAULT '',
        max_load TEXT NOT NULL DEFAULT '',
        modem_no TEXT NOT NULL DEFAULT '',
        sensor_id TEXT NOT NULL DEFAULT '',
        camera_id TEXT NOT NULL DEFAULT '',
        empty_gross_weight TEXT NOT NULL DEFAULT '',
        empty_error_rate TEXT NOT NULL DEFAULT '',
        full_gross_weight TEXT NOT NULL DEFAULT '',
        full_error_rate TEXT NOT NULL DEFAULT '',
        ch1 TEXT NOT NULL DEFAULT '',
        ch2 TEXT NOT NULL DEFAULT '',
        ch3 TEXT NOT NULL DEFAULT '',
        ch4 TEXT NOT NULL DEFAULT '',
        ch5 TEXT NOT NULL DEFAULT '',
        ch6 TEXT NOT NULL DEFAULT '',
        ch7 TEXT NOT NULL DEFAULT '',
        ch8 TEXT NOT NULL DEFAULT '',
        scale_empty_ax1 TEXT NOT NULL DEFAULT '',
        scale_empty_ax2 TEXT NOT NULL DEFAULT '',
        scale_empty_ax3 TEXT NOT NULL DEFAULT '',
        scale_empty_ax4 TEXT NOT NULL DEFAULT '',
        scale_empty_total TEXT NOT NULL DEFAULT '',
        scale_full_ax1 TEXT NOT NULL DEFAULT '',
        scale_full_ax2 TEXT NOT NULL DEFAULT '',
        scale_full_ax3 TEXT NOT NULL DEFAULT '',
        scale_full_ax4 TEXT NOT NULL DEFAULT '',
        scale_full_total TEXT NOT NULL DEFAULT '',
        scale_type TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE slot_photos (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        slot_key TEXT NOT NULL,
        photo_path TEXT NOT NULL
      )
    ''');

    await _seedVehicles(db);
  }

  Future<void> _seedVehicles(Database db) async {
    final rows = [
      [
        1,
        '86누0773',
        '남원그린영농조합법인',
        '현대',
        '3',
        '38',
        '23',
        '012-3328-8152',
        'RLS21-008',
        'CA21-008'
      ],
      [
        2,
        '82서3492',
        '남원그린영농조합법인',
        '대우',
        '3',
        '38',
        '',
        '012-2135-9650',
        'WS2015-034',
        'CA15-034'
      ],
      [
        3,
        '80저0939',
        '남원양돈협회영농조합법인',
        '대우',
        '3',
        '38',
        '23',
        '012-2147-4491',
        'WS2015-071',
        'CA15-071'
      ],
      [
        4,
        '81조6496',
        '남원양돈협회영농조합법인',
        '대우',
        '3',
        '38',
        '23',
        '012-2147-4479',
        'WS2015-079',
        'CA15-079'
      ],
      [
        5,
        '94수4881',
        '남원양돈협회영농조합법인',
        '현대',
        '3',
        '38',
        '23',
        '012-4108-6655',
        'T2-STR22-145',
        'CA22-145'
      ],
      [
        6,
        '80저0970',
        '남원축협',
        '현대',
        '3',
        '38',
        '23',
        '012-2941-1957',
        'RLS-091',
        'CALS-091'
      ],
      [
        7,
        '95나1902',
        '남원축협',
        '현대',
        '3',
        '38',
        '23',
        '012-2147-4474',
        'WS2015-082',
        'CA15-082'
      ],
      [
        8,
        '80저0997',
        '에코바이오영농조합법인',
        '현대',
        '3',
        '15',
        '8',
        '012-4108-6654',
        'T2-STR22-144',
        'CA22-144'
      ],
      [
        9,
        '81조6470',
        '에코바이오영농조합법인',
        '현대',
        '3',
        '15',
        '8',
        '012-4108-6652',
        'T2-STR22-142',
        'CA22-142'
      ],
      [
        10,
        '95가9142',
        '에코바이오영농조합법인',
        '현대',
        '3',
        '15',
        '8',
        '012-2131-5555',
        'WS2015-235',
        'CA15-235'
      ],
      [
        11,
        '96부6117',
        '에코바이오영농조합법인',
        '대우',
        '3',
        '15',
        '8',
        '012-4108-6653',
        'T2-STR22-143',
        'CA22-143'
      ],
      [
        12,
        '94수4700',
        '영농조합법인서남원',
        '볼보',
        '3',
        '15',
        '8',
        '012-4119-2314',
        'T3-STR22-067',
        'CA22-067'
      ],
      [
        13,
        '94수4790',
        '영농조합법인서남원',
        '볼보',
        '3',
        '15',
        '8',
        '012-4119-2282',
        'T3-STR22-047',
        'CA22-047'
      ],
      [
        14,
        '94수4999',
        '친환경현대그린영농조합법인',
        '현대',
        '3',
        '15',
        '8',
        '012-4108-6686',
        'T3-STR22-009',
        'CA22-009'
      ],
      [
        15,
        '90러8789',
        '친환경현대그린영농조합법인',
        '현대',
        '3',
        '15',
        '8',
        '012-5564-0030',
        'T3-25-030',
        'CA25-030'
      ],
    ];
    for (final r in rows) {
      await db.insert('vehicles', {
        'id': _uuid.v4(),
        'serial_no': r[0],
        'plate_no': r[1],
        'owner': r[2],
        'vehicle_type': r[3],
        'axle_count': r[4],
        'gross_weight': r[5],
        'max_load': r[6],
        'modem_no': r[7],
        'sensor_id': r[8],
        'camera_id': r[9],
      });
    }
  }

  // ─── Photo path helpers ────────────────────────────────────────────────
  static String? _photoBasePath;

  static Future<String> getPhotoBasePath() async {
    if (_photoBasePath != null) return _photoBasePath!;
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create(recursive: true);
    _photoBasePath = photoDir.path;
    return _photoBasePath!;
  }

  // ─── Vehicle CRUD ──────────────────────────────────────────────────────
  Future<List<Vehicle>> getVehicles() async {
    final db = await database;
    final maps = await db.query('vehicles', orderBy: 'serial_no ASC');
    return maps.map((m) => Vehicle.fromMap(m)).toList();
  }

  Future<Vehicle?> findVehicleByPlate(String plateNo) async {
    final db = await database;
    final clean = plateNo.replaceAll(RegExp(r'\s+'), '');
    final all = await db.query('vehicles');
    for (final m in all) {
      final dbPlate = (m['plate_no'] as String).replaceAll(RegExp(r'\s+'), '');
      if (dbPlate == clean) return Vehicle.fromMap(m);
    }
    return null;
  }

  Future<String> addVehicle(Vehicle v) async {
    final db = await database;
    await db.insert('vehicles', v.toMap());
    return v.id;
  }

  Future<void> updateVehicle(Vehicle v) async {
    final db = await database;
    await db.update('vehicles', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
  }

  Future<void> deleteVehicle(String id) async {
    final db = await database;
    await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  // 새 점검에서 등록된 차량을 차량 목록에 자동 추가
  Future<void> syncVehicleFromInspection(InspectionRecord rec) async {
    if (rec.plateNo.isEmpty) return;
    final existing = await findVehicleByPlate(rec.plateNo);
    if (existing != null) return; // 이미 있으면 스킵
    final db = await database;
    final countMap =
        await db.rawQuery('SELECT MAX(serial_no) as mx FROM vehicles');
    final nextSerial = ((countMap.first['mx'] as int?) ?? 0) + 1;
    await db.insert('vehicles', {
      'id': _uuid.v4(),
      'serial_no': nextSerial,
      'plate_no': rec.plateNo,
      'owner': rec.driverOrg,
      'vehicle_type': rec.vehicleType,
      'axle_count': rec.axleCount,
      'gross_weight': rec.grossWeight,
      'max_load': rec.maxLoad,
      'modem_no': rec.modemNo,
      'sensor_id': rec.sensorId,
      'camera_id': rec.cameraId,
    });
  }

  // ─── Inspection CRUD ───────────────────────────────────────────────────
  Future<List<InspectionRecord>> getInspections() async {
    final db = await database;
    final maps = await db.query('inspections', orderBy: 'created_at DESC');
    final records = maps.map((m) => InspectionRecord.fromMap(m)).toList();
    for (final rec in records) {
      rec.photos = await _loadPhotos(rec.id);
    }
    return records;
  }

  Future<InspectionRecord?> getInspection(String id) async {
    final db = await database;
    final maps =
        await db.query('inspections', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final rec = InspectionRecord.fromMap(maps.first);
    rec.photos = await _loadPhotos(id);
    return rec;
  }

  Future<List<SlotPhoto>> _loadPhotos(String inspectionId) async {
    final db = await database;
    final base = await getPhotoBasePath();
    final maps = await db.query('slot_photos',
        where: 'inspection_id = ?', whereArgs: [inspectionId]);
    return maps.map((m) {
      final photo = SlotPhoto.fromMap(m);
      final fileName = photo.photoPath.split(RegExp(r'[/\\]')).last;
      photo.photoPath = '$base/$fileName';
      return photo;
    }).toList();
  }

  Future<String> saveInspection({
    required InspectionRecord record,
    required Map<String, String> slotPaths,
    String? existingId,
  }) async {
    final db = await database;
    final id = existingId ?? record.id;
    await db.delete('slot_photos', where: 'inspection_id = ?', whereArgs: [id]);
    await db.delete('inspections', where: 'id = ?', whereArgs: [id]);

    final map = record.toMap();
    map['id'] = id;
    await db.insert('inspections', map);

    for (final entry in slotPaths.entries) {
      final fileName = entry.value.split(RegExp(r'[/\\]')).last;
      await db.insert('slot_photos', {
        'id': _uuid.v4(),
        'inspection_id': id,
        'slot_key': entry.key,
        'photo_path': fileName,
      });
    }

    // 점검 저장 시 차량 목록에도 자동 동기화
    await _syncVehicleFromInspection(record);

    return id;
  }

  Future<void> _syncVehicleFromInspection(InspectionRecord rec) async {
    if (rec.plateNo.isEmpty) return;
    final existing = await findVehicleByPlate(rec.plateNo);
    if (existing != null) return; // 이미 있으면 패스
    // 차량 목록에 없으면 새로 추가
    final db = await database;
    final countMap =
        await db.rawQuery('SELECT MAX(serial_no) as mx FROM vehicles');
    final nextSerial = ((countMap.first['mx'] as int?) ?? 0) + 1;
    await db.insert('vehicles', {
      'id': _uuid.v4(),
      'serial_no': nextSerial,
      'plate_no': rec.plateNo,
      'owner': rec.driverOrg,
      'vehicle_type': rec.vehicleType,
      'axle_count': rec.axleCount,
      'gross_weight': rec.grossWeight,
      'max_load': rec.maxLoad,
      'modem_no': rec.modemNo,
      'sensor_id': rec.sensorId,
      'camera_id': rec.cameraId,
    });
  }

  Future<void> deleteInspection(String id) async {
    final db = await database;
    await db.delete('slot_photos', where: 'inspection_id = ?', whereArgs: [id]);
    await db.delete('inspections', where: 'id = ?', whereArgs: [id]);
  }
}
