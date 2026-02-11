/// Event severity levels
enum Severity {
  info('INFO'),
  warning('WARNING'),
  critical('CRITICAL');

  final String value;
  const Severity(this.value);

  static Severity fromString(String value) {
    return Severity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Severity.info,
    );
  }
}

/// Event types
enum EventType {
  roiIntrusion('ROI_INTRUSION'),
  ppeHelmetMissing('PPE_HELMET_MISSING'),
  ppeMaskMissing('PPE_MASK_MISSING'),
  fireExtinguisherMissing('FIRE_EXTINGUISHER_MISSING');

  final String value;
  const EventType(this.value);

  static EventType fromString(String value) {
    return EventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventType.roiIntrusion,
    );
  }

  String get displayName {
    switch (this) {
      case EventType.roiIntrusion:
        return 'ROI 진입';
      case EventType.ppeHelmetMissing:
        return '안전모 미착용';
      case EventType.ppeMaskMissing:
        return '마스크 미착용';
      case EventType.fireExtinguisherMissing:
        return '소화기 미비치';
    }
  }
}

/// Safety event model
class SafetyEvent {
  final int id;
  final int cameraId;
  final String eventType;
  final String severity;
  final String message;
  final int? roiId;
  final String? snapshotPath;
  final Map<String, dynamic>? detectionData;
  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;

  SafetyEvent({
    required this.id,
    required this.cameraId,
    required this.eventType,
    required this.severity,
    required this.message,
    this.roiId,
    this.snapshotPath,
    this.detectionData,
    required this.isAcknowledged,
    this.acknowledgedAt,
    required this.createdAt,
  });

  factory SafetyEvent.fromJson(Map<String, dynamic> json) {
    return SafetyEvent(
      id: json['id'],
      cameraId: json['camera_id'],
      eventType: json['event_type'],
      severity: json['severity'],
      message: json['message'],
      roiId: json['roi_id'],
      snapshotPath: json['snapshot_path'],
      detectionData: json['detection_data'] != null
          ? (json['detection_data'] is String
              ? null
              : json['detection_data'] as Map<String, dynamic>)
          : null,
      isAcknowledged: json['is_acknowledged'] ?? false,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Severity get severityEnum => Severity.fromString(severity);
  EventType get eventTypeEnum => EventType.fromString(eventType);
}
