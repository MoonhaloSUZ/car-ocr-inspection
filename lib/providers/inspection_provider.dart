import 'package:flutter/material.dart';
import '../models/inspection.dart';
import '../services/database_service.dart';

class InspectionFilter {
  final String? location;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const InspectionFilter({this.location, this.dateFrom, this.dateTo});

  bool get hasFilter =>
      (location != null && location!.isNotEmpty) ||
      dateFrom != null ||
      dateTo != null;

  InspectionFilter copyWith({
    String? location,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearLocation = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) =>
      InspectionFilter(
        location: clearLocation ? null : location ?? this.location,
        dateFrom: clearDateFrom ? null : dateFrom ?? this.dateFrom,
        dateTo: clearDateTo ? null : dateTo ?? this.dateTo,
      );
}

class InspectionProvider extends ChangeNotifier {
  final _db = DatabaseService();

  List<Inspection> _inspections = [];
  InspectionFilter _filter = const InspectionFilter();
  bool _loading = false;
  List<String> _locations = [];

  List<Inspection> get inspections => _inspections;
  InspectionFilter get filter => _filter;
  bool get loading => _loading;
  List<String> get locations => _locations;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await reload();
    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    _inspections = await _db.getInspections(
      locationFilter: _filter.location,
      dateFrom: _filter.dateFrom,
      dateTo: _filter.dateTo,
    );
    _locations = await _db.getDistinctLocations();
    notifyListeners();
  }

  Future<void> applyFilter(InspectionFilter filter) async {
    _filter = filter;
    await reload();
  }

  Future<void> clearFilter() async {
    _filter = const InspectionFilter();
    await reload();
  }

  Future<void> deleteInspection(String id) async {
    await _db.deleteInspection(id);
    _inspections.removeWhere((i) => i.id == id);
    notifyListeners();
  }
}
