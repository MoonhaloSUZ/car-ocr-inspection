import 'package:flutter/material.dart';
import '../models/checklist_template.dart';
import '../services/database_service.dart';

class TemplateProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<ChecklistCategory> _categories = [];
  bool _loading = false;

  List<ChecklistCategory> get categories => _categories;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await reload();
    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    _categories = await _db.getTemplate();
    notifyListeners();
  }

  Future<void> addCategory(String title) async {
    final order = _categories.length + 1;
    await _db.addCategory(title, order);
    await reload();
  }

  Future<void> updateCategory(String id, String title) async {
    await _db.updateCategory(id, title);
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _categories[idx].title = title;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();
    await _db.reorderCategories(_categories);
  }

  Future<void> addItem(String categoryId, String title) async {
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final order = cat.items.length + 1;
    final id = await _db.addItem(categoryId, title, order);
    cat.items.add(
      ChecklistItem(
          id: id, categoryId: categoryId, title: title, sortOrder: order),
    );
    notifyListeners();
  }

  Future<void> updateItem(String id, String title) async {
    await _db.updateItem(id, title);
    for (final cat in _categories) {
      final idx = cat.items.indexWhere((i) => i.id == id);
      if (idx != -1) {
        cat.items[idx].title = title;
        notifyListeners();
        break;
      }
    }
  }

  Future<void> deleteItem(String id) async {
    await _db.deleteItem(id);
    for (final cat in _categories) {
      cat.items.removeWhere((i) => i.id == id);
    }
    notifyListeners();
  }

  Future<void> reorderItems(
      String categoryId, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final item = cat.items.removeAt(oldIndex);
    cat.items.insert(newIndex, item);
    notifyListeners();
    await _db.reorderItems(cat.items);
  }
}
