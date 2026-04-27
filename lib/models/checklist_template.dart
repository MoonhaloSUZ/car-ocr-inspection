class ChecklistCategory {
  final String id;
  String title;
  int sortOrder;
  List<ChecklistItem> items;

  ChecklistCategory({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.items = const [],
  });

  factory ChecklistCategory.fromMap(Map<String, dynamic> map) =>
      ChecklistCategory(
        id: map['id'] as String,
        title: map['title'] as String,
        sortOrder: map['sort_order'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'sort_order': sortOrder,
      };

  ChecklistCategory copyWith({
    String? id,
    String? title,
    int? sortOrder,
    List<ChecklistItem>? items,
  }) =>
      ChecklistCategory(
        id: id ?? this.id,
        title: title ?? this.title,
        sortOrder: sortOrder ?? this.sortOrder,
        items: items ?? this.items,
      );
}

class ChecklistItem {
  final String id;
  final String categoryId;
  String title;
  int sortOrder;

  ChecklistItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.sortOrder,
  });

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String,
        categoryId: map['category_id'] as String,
        title: map['title'] as String,
        sortOrder: map['sort_order'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'title': title,
        'sort_order': sortOrder,
      };

  ChecklistItem copyWith({
    String? id,
    String? categoryId,
    String? title,
    int? sortOrder,
  }) =>
      ChecklistItem(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        title: title ?? this.title,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
