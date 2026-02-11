/// Camera model
class Camera {
  final int id;
  final String name;
  final String source;
  final String sourceType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Camera({
    required this.id,
    required this.name,
    required this.source,
    required this.sourceType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'],
      name: json['name'],
      source: json['source'],
      sourceType: json['source_type'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source': source,
      'source_type': sourceType,
      'is_active': isActive,
    };
  }
}

/// Camera creation request
class CameraCreate {
  final String name;
  final String source;
  final String sourceType;

  CameraCreate({
    required this.name,
    required this.source,
    this.sourceType = 'file',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'source': source,
      'source_type': sourceType,
    };
  }
}
