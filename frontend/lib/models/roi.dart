/// Point model for ROI vertices
class Point {
  final double x;
  final double y;

  Point({required this.x, required this.y});

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// ROI (Region of Interest) model
class ROI {
  final int id;
  final int cameraId;
  final String name;
  final List<Point> points;
  final String color;
  final String zoneType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ROI({
    required this.id,
    required this.cameraId,
    required this.name,
    required this.points,
    required this.color,
    required this.zoneType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ROI.fromJson(Map<String, dynamic> json) {
    return ROI(
      id: json['id'],
      cameraId: json['camera_id'],
      name: json['name'],
      points: (json['points'] as List).map((p) => Point.fromJson(p)).toList(),
      color: json['color'],
      zoneType: json['zone_type'] ?? 'warning',
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'camera_id': cameraId,
      'name': name,
      'points': points.map((p) => p.toJson()).toList(),
      'color': color,
      'zone_type': zoneType,
      'is_active': isActive,
    };
  }
}

/// ROI creation request
class ROICreate {
  final int cameraId;
  final String name;
  final List<Point> points;
  final String color;
  final String zoneType;

  ROICreate({
    required this.cameraId,
    required this.name,
    required this.points,
    this.color = '#FF0000',
    this.zoneType = 'warning',
  });

  Map<String, dynamic> toJson() {
    return {
      'camera_id': cameraId,
      'name': name,
      'points': points.map((p) => p.toJson()).toList(),
      'color': color,
      'zone_type': zoneType,
    };
  }
}
