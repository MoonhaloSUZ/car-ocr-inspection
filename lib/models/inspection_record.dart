class PhotoSlot {
  final String key;
  final String label;
  const PhotoSlot({required this.key, required this.label});
}

const List<PhotoSlot> kPhotoSlots = [
  PhotoSlot(key: 'front', label: '차량 정면'),
  PhotoSlot(key: 'side', label: '차량 측면'),
  PhotoSlot(key: 'weight_sensor', label: '중량센서'),
  PhotoSlot(key: 'terminal', label: '차량 단말기'),
  PhotoSlot(key: 'gps_camera', label: 'GPS, IR카메라, 통신모뎀'),
  PhotoSlot(key: 'interior', label: '차량내부'),
  PhotoSlot(key: 'equip_main', label: '검증장비 메인화면'),
  PhotoSlot(key: 'veh_sensor', label: '차량 센서'),
  PhotoSlot(key: 'before_repair', label: '유지보수 전'),
  PhotoSlot(key: 'after_repair', label: '유지보수 후'),
];

class SlotPhoto {
  final String id;
  final String inspectionId;
  final String slotKey;
  String photoPath;

  SlotPhoto({
    required this.id,
    required this.inspectionId,
    required this.slotKey,
    required this.photoPath,
  });

  factory SlotPhoto.fromMap(Map<String, dynamic> m) => SlotPhoto(
        id: m['id'] as String,
        inspectionId: m['inspection_id'] as String,
        slotKey: m['slot_key'] as String,
        photoPath: m['photo_path'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'inspection_id': inspectionId,
        'slot_key': slotKey,
        'photo_path': photoPath,
      };
}

class InspectionRecord {
  final String id;
  final DateTime createdAt;

  // 헤더
  String mgmtNo; // 관리번호
  String inspectionDate;
  String driverOrg;
  String driverName;
  String driverContact;

  // 차량정보
  String plateNo;
  String vehicleType;
  String grossWeight;
  String axleCount;
  String maxLoad;

  // 장비 정보
  String modemNo;
  String sensorId;
  String cameraId;

  // 중량센서(A) - 공차
  String emptyGrossWeight;
  String emptyErrorRate;
  // 중량센서(A) - 만차
  String fullGrossWeight;
  String fullErrorRate;
  // 공만차편차 CH1~CH8
  String ch1;
  String ch2;
  String ch3;
  String ch4;
  String ch5;
  String ch6;
  String ch7;
  String ch8;

  // 계근대(B) - 공차 축중량
  String scaleEmptyAx1;
  String scaleEmptyAx2;
  String scaleEmptyAx3;
  String scaleEmptyAx4;
  String scaleEmptyTotal;
  // 계근대(B) - 만차 축중량
  String scaleFullAx1;
  String scaleFullAx2;
  String scaleFullAx3;
  String scaleFullAx4;
  String scaleFullTotal;
  // 계근대 타입
  String scaleType; // '계근대' | '이동식축중기' | ''

  List<SlotPhoto> photos;

  InspectionRecord({
    required this.id,
    required this.createdAt,
    this.mgmtNo = '',
    this.inspectionDate = '',
    this.driverOrg = '',
    this.driverName = '',
    this.driverContact = '',
    this.plateNo = '',
    this.vehicleType = '',
    this.grossWeight = '',
    this.axleCount = '',
    this.maxLoad = '',
    this.modemNo = '',
    this.sensorId = '',
    this.cameraId = '',
    this.emptyGrossWeight = '',
    this.emptyErrorRate = '',
    this.fullGrossWeight = '',
    this.fullErrorRate = '',
    this.ch1 = '',
    this.ch2 = '',
    this.ch3 = '',
    this.ch4 = '',
    this.ch5 = '',
    this.ch6 = '',
    this.ch7 = '',
    this.ch8 = '',
    this.scaleEmptyAx1 = '',
    this.scaleEmptyAx2 = '',
    this.scaleEmptyAx3 = '',
    this.scaleEmptyAx4 = '',
    this.scaleEmptyTotal = '',
    this.scaleFullAx1 = '',
    this.scaleFullAx2 = '',
    this.scaleFullAx3 = '',
    this.scaleFullAx4 = '',
    this.scaleFullTotal = '',
    this.scaleType = '',
    this.photos = const [],
  });

  factory InspectionRecord.fromMap(Map<String, dynamic> m) {
    String s(String key) => m[key] as String? ?? '';
    return InspectionRecord(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      mgmtNo: s('mgmt_no'),
      inspectionDate: s('inspection_date'),
      driverOrg: s('driver_org'),
      driverName: s('driver_name'),
      driverContact: s('driver_contact'),
      plateNo: s('plate_no'),
      vehicleType: s('vehicle_type'),
      grossWeight: s('gross_weight'),
      axleCount: s('axle_count'),
      maxLoad: s('max_load'),
      modemNo: s('modem_no'),
      sensorId: s('sensor_id'),
      cameraId: s('camera_id'),
      emptyGrossWeight: s('empty_gross_weight'),
      emptyErrorRate: s('empty_error_rate'),
      fullGrossWeight: s('full_gross_weight'),
      fullErrorRate: s('full_error_rate'),
      ch1: s('ch1'),
      ch2: s('ch2'),
      ch3: s('ch3'),
      ch4: s('ch4'),
      ch5: s('ch5'),
      ch6: s('ch6'),
      ch7: s('ch7'),
      ch8: s('ch8'),
      scaleEmptyAx1: s('scale_empty_ax1'),
      scaleEmptyAx2: s('scale_empty_ax2'),
      scaleEmptyAx3: s('scale_empty_ax3'),
      scaleEmptyAx4: s('scale_empty_ax4'),
      scaleEmptyTotal: s('scale_empty_total'),
      scaleFullAx1: s('scale_full_ax1'),
      scaleFullAx2: s('scale_full_ax2'),
      scaleFullAx3: s('scale_full_ax3'),
      scaleFullAx4: s('scale_full_ax4'),
      scaleFullTotal: s('scale_full_total'),
      scaleType: s('scale_type'),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'mgmt_no': mgmtNo,
        'inspection_date': inspectionDate,
        'driver_org': driverOrg,
        'driver_name': driverName,
        'driver_contact': driverContact,
        'plate_no': plateNo,
        'vehicle_type': vehicleType,
        'gross_weight': grossWeight,
        'axle_count': axleCount,
        'max_load': maxLoad,
        'modem_no': modemNo,
        'sensor_id': sensorId,
        'camera_id': cameraId,
        'empty_gross_weight': emptyGrossWeight,
        'empty_error_rate': emptyErrorRate,
        'full_gross_weight': fullGrossWeight,
        'full_error_rate': fullErrorRate,
        'ch1': ch1,
        'ch2': ch2,
        'ch3': ch3,
        'ch4': ch4,
        'ch5': ch5,
        'ch6': ch6,
        'ch7': ch7,
        'ch8': ch8,
        'scale_empty_ax1': scaleEmptyAx1,
        'scale_empty_ax2': scaleEmptyAx2,
        'scale_empty_ax3': scaleEmptyAx3,
        'scale_empty_ax4': scaleEmptyAx4,
        'scale_empty_total': scaleEmptyTotal,
        'scale_full_ax1': scaleFullAx1,
        'scale_full_ax2': scaleFullAx2,
        'scale_full_ax3': scaleFullAx3,
        'scale_full_ax4': scaleFullAx4,
        'scale_full_total': scaleFullTotal,
        'scale_type': scaleType,
      };

  int get filledPhotoCount => photos.length;
}
