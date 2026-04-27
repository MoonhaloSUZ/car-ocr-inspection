import 'package:flutter/material.dart';
import '../models/inspection_record.dart';
import '../services/database_service.dart';

class InspectionProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<InspectionRecord> _records = [];
  bool _loading = false;

  List<InspectionRecord> get records => _records;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await reload();
    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    _records = await _db.getInspections();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _db.deleteInspection(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
