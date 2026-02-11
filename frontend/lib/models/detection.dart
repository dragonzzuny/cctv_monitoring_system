/// Detection bounding box
class DetectionBox {
  final int classId;
  final String className;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double centerX;
  final double centerY;
  final int? trackId;

  DetectionBox({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.centerX,
    required this.centerY,
    this.trackId,
  });

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    return DetectionBox(
      classId: json['class_id'],
      className: json['class_name'],
      confidence: (json['confidence'] as num).toDouble(),
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
      centerX: (json['center_x'] as num).toDouble(),
      centerY: (json['center_y'] as num).toDouble(),
      trackId: json['track_id'],
    );
  }

  double get width => x2 - x1;
  double get height => y2 - y1;
}

/// Detection result for a frame
class DetectionResult {
  final int frameNumber;
  final double timestamp;
  final List<DetectionBox> detections;
  final int personsCount;
  final int helmetsCount;
  final int masksCount;
  final int fireExtinguishersCount;

  DetectionResult({
    required this.frameNumber,
    required this.timestamp,
    required this.detections,
    this.personsCount = 0,
    this.helmetsCount = 0,
    this.masksCount = 0,
    this.fireExtinguishersCount = 0,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      frameNumber: json['frame_number'],
      timestamp: (json['timestamp'] as num).toDouble(),
      detections: (json['detections'] as List)
          .map((d) => DetectionBox.fromJson(d))
          .toList(),
      personsCount: json['persons_count'] ?? 0,
      helmetsCount: json['helmets_count'] ?? 0,
      masksCount: json['masks_count'] ?? 0,
      fireExtinguishersCount: json['fire_extinguishers_count'] ?? 0,
    );
  }
}

/// Stream frame data from WebSocket
class StreamFrame {
  final int cameraId;
  final String frameBase64;
  final double currentMs;
  final double totalMs;
  final DetectionResult? detection;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> rois;
  final Map<String, dynamic> roiMetrics;

  StreamFrame({
    required this.cameraId,
    required this.frameBase64,
    this.currentMs = 0.0,
    this.totalMs = 0.0,
    this.detection,
    this.events = const [],
    this.rois = const [],
    this.roiMetrics = const {},
  });

  factory StreamFrame.fromJson(Map<String, dynamic> json) {
    return StreamFrame(
      cameraId: json['camera_id'],
      frameBase64: json['frame'],
      currentMs: (json['current_ms'] as num?)?.toDouble() ?? 0.0,
      totalMs: (json['total_ms'] as num?)?.toDouble() ?? 0.0,
      detection: json['detection'] != null
          ? DetectionResult.fromJson(json['detection'])
          : null,
      events: json['events'] != null
          ? List<Map<String, dynamic>>.from(json['events'])
          : [],
      rois: json['rois'] != null
          ? List<Map<String, dynamic>>.from(json['rois'])
          : [],
      roiMetrics: json['roi_metrics'] != null
          ? Map<String, dynamic>.from(json['roi_metrics'])
          : {},
    );
  }
}
