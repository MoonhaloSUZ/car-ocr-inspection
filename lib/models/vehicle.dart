class Vehicle {
  final String id;
  int serialNo;
  String plateNo;
  String owner;
  String vehicleType;
  String axleCount;
  String grossWeight;
  String maxLoad;
  String modemNo;
  String sensorId;
  String cameraId;

  Vehicle({
    required this.id,
    required this.serialNo,
    required this.plateNo,
    required this.owner,
    required this.vehicleType,
    required this.axleCount,
    required this.grossWeight,
    required this.maxLoad,
    required this.modemNo,
    required this.sensorId,
    required this.cameraId,
  });

  factory Vehicle.fromMap(Map<String, dynamic> m) => Vehicle(
        id: m['id'] as String,
        serialNo: m['serial_no'] as int? ?? 0,
        plateNo: m['plate_no'] as String? ?? '',
        owner: m['owner'] as String? ?? '',
        vehicleType: m['vehicle_type'] as String? ?? '',
        axleCount: m['axle_count'] as String? ?? '',
        grossWeight: m['gross_weight'] as String? ?? '',
        maxLoad: m['max_load'] as String? ?? '',
        modemNo: m['modem_no'] as String? ?? '',
        sensorId: m['sensor_id'] as String? ?? '',
        cameraId: m['camera_id'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'serial_no': serialNo,
        'plate_no': plateNo,
        'owner': owner,
        'vehicle_type': vehicleType,
        'axle_count': axleCount,
        'gross_weight': grossWeight,
        'max_load': maxLoad,
        'modem_no': modemNo,
        'sensor_id': sensorId,
        'camera_id': cameraId,
      };
}
