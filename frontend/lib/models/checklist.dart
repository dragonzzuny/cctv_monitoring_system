/// Checklist item model
class ChecklistItem {
  final int id;
  final int checklistId;
  final String itemType;
  final String description;
  final bool isChecked;
  final bool autoChecked;
  final DateTime? checkedAt;
  final DateTime createdAt;

  ChecklistItem({
    required this.id,
    required this.checklistId,
    required this.itemType,
    required this.description,
    required this.isChecked,
    required this.autoChecked,
    this.checkedAt,
    required this.createdAt,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'],
      checklistId: json['checklist_id'],
      itemType: json['item_type'],
      description: json['description'],
      isChecked: json['is_checked'],
      autoChecked: json['auto_checked'],
      checkedAt: json['checked_at'] != null
          ? DateTime.parse(json['checked_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  ChecklistItem copyWith({bool? isChecked, bool? autoChecked}) {
    return ChecklistItem(
      id: id,
      checklistId: checklistId,
      itemType: itemType,
      description: description,
      isChecked: isChecked ?? this.isChecked,
      autoChecked: autoChecked ?? this.autoChecked,
      checkedAt: checkedAt,
      createdAt: createdAt,
    );
  }
}

/// Checklist model
class Checklist {
  final int id;
  final int cameraId;
  final String name;
  final bool isActive;
  final List<ChecklistItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Checklist({
    required this.id,
    required this.cameraId,
    required this.name,
    required this.isActive,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Checklist.fromJson(Map<String, dynamic> json) {
    return Checklist(
      id: json['id'],
      cameraId: json['camera_id'],
      name: json['name'],
      isActive: json['is_active'],
      items: (json['items'] as List)
          .map((item) => ChecklistItem.fromJson(item))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  int get checkedCount => items.where((item) => item.isChecked).length;
  int get totalCount => items.length;
  double get progress => totalCount > 0 ? checkedCount / totalCount : 0.0;
}
