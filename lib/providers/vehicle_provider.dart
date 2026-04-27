import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';

class VehicleProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<Vehicle> _vehicles = [];
  bool _loading = false;

  List<Vehicle> get vehicles => _vehicles;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await reload();
    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    _vehicles = await _db.getVehicles();
    notifyListeners();
  }

  Future<Vehicle?> findByPlate(String plateNo) =>
      _db.findVehicleByPlate(plateNo);

  Future<void> addVehicle(Vehicle v) async {
    await _db.addVehicle(v);
    await reload();
  }

  Future<void> updateVehicle(Vehicle v) async {
    await _db.updateVehicle(v);
    final i = _vehicles.indexWhere((x) => x.id == v.id);
    if (i != -1) {
      _vehicles[i] = v;
      notifyListeners();
    }
  }

  Future<void> deleteVehicle(String id) async {
    await _db.deleteVehicle(id);
    _vehicles.removeWhere((v) => v.id == id);
    notifyListeners();
  }
}
