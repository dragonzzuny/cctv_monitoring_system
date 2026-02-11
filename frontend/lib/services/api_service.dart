import 'package:dio/dio.dart';
import '../models/models.dart';

/// API service for backend communication
class ApiService {
  final Dio _dio;
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8001'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout) {
          throw Exception('백엔드 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인하세요.');
        }
        handler.next(error);
      },
    ));
  }

  // ==================== Camera APIs ====================

  Future<List<Camera>> getCameras({bool activeOnly = false}) async {
    final response = await _dio.get('/api/cameras', queryParameters: {
      if (activeOnly) 'active_only': true,
    });
    return (response.data as List).map((c) => Camera.fromJson(c)).toList();
  }

  Future<Camera> getCamera(int cameraId) async {
    final response = await _dio.get('/api/cameras/$cameraId');
    return Camera.fromJson(response.data);
  }

  Future<Camera> createCamera(CameraCreate camera) async {
    final response = await _dio.post('/api/cameras/', data: camera.toJson());
    return Camera.fromJson(response.data);
  }

  Future<Camera> updateCamera(int cameraId, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/cameras/$cameraId', data: data);
    return Camera.fromJson(response.data);
  }

  Future<void> deleteCamera(int cameraId) async {
    await _dio.delete('/api/cameras/$cameraId');
  }

  // ==================== ROI APIs ====================

  Future<List<ROI>> getRois({int? cameraId, bool activeOnly = false}) async {
    final response = await _dio.get('/api/rois', queryParameters: {
      if (cameraId != null) 'camera_id': cameraId,
      if (activeOnly) 'active_only': true,
    });
    return (response.data as List).map((r) => ROI.fromJson(r)).toList();
  }

  Future<ROI> createRoi(ROICreate roi) async {
    final response = await _dio.post('/api/rois/', data: roi.toJson());
    return ROI.fromJson(response.data);
  }

  Future<ROI> updateRoi(int roiId, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/rois/$roiId', data: data);
    return ROI.fromJson(response.data);
  }

  Future<void> deleteRoi(int roiId) async {
    await _dio.delete('/api/rois/$roiId');
  }

  // ==================== Event APIs ====================

  Future<List<SafetyEvent>> getEvents({
    int? cameraId,
    String? eventType,
    String? severity,
    bool? acknowledged,
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get('/api/events', queryParameters: {
      if (cameraId != null) 'camera_id': cameraId,
      if (eventType != null) 'event_type': eventType,
      if (severity != null) 'severity': severity,
      if (acknowledged != null) 'acknowledged': acknowledged,
      'skip': skip,
      'limit': limit,
    });
    return (response.data as List).map((e) => SafetyEvent.fromJson(e)).toList();
  }

  Future<List<SafetyEvent>> getUnacknowledgedEvents({int? cameraId}) async {
    final response = await _dio.get('/api/events/unacknowledged', queryParameters: {
      if (cameraId != null) 'camera_id': cameraId,
    });
    return (response.data as List).map((e) => SafetyEvent.fromJson(e)).toList();
  }

  Future<List<SafetyEvent>> getRecentEvents({int count = 10, int? cameraId}) async {
    final response = await _dio.get('/api/events/recent', queryParameters: {
      'count': count,
      if (cameraId != null) 'camera_id': cameraId,
    });
    return (response.data as List).map((e) => SafetyEvent.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getEventStatistics({int? cameraId}) async {
    final response = await _dio.get('/api/events/statistics', queryParameters: {
      if (cameraId != null) 'camera_id': cameraId,
    });
    return response.data;
  }

  Future<SafetyEvent> acknowledgeEvent(int eventId) async {
    final response = await _dio.post('/api/events/$eventId/acknowledge');
    return SafetyEvent.fromJson(response.data);
  }

  Future<int> acknowledgeAllEvents({int? cameraId}) async {
    final response = await _dio.post('/api/events/acknowledge-all', queryParameters: {
      if (cameraId != null) 'camera_id': cameraId,
    });
    return response.data['acknowledged'];
  }

  // ==================== Checklist APIs ====================

  Future<List<Checklist>> getChecklists({int? cameraId, bool activeOnly = false}) async {
    final response = await _dio.get('/api/checklists', queryParameters: {
      if (cameraId != null) 'camera_id': cameraId,
      if (activeOnly) 'active_only': true,
    });
    return (response.data as List).map((c) => Checklist.fromJson(c)).toList();
  }

  Future<Checklist> createDefaultChecklist(int cameraId) async {
    final response = await _dio.post('/api/checklists/camera/$cameraId/default');
    return Checklist.fromJson(response.data);
  }

  Future<ChecklistItem> updateChecklistItem(int itemId, bool isChecked) async {
    final response = await _dio.put('/api/checklists/items/$itemId', data: {
      'is_checked': isChecked,
    });
    return ChecklistItem.fromJson(response.data);
  }

  Future<Checklist> resetChecklist(int checklistId) async {
    final response = await _dio.post('/api/checklists/$checklistId/reset');
    return Checklist.fromJson(response.data);
  }

  // ==================== Stream APIs ====================

  Future<Map<String, dynamic>> getSnapshot(int cameraId, {bool withDetection = false}) async {
    final response = await _dio.get('/api/stream/$cameraId/snapshot', queryParameters: {
      'with_detection': withDetection,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getStreamInfo(int cameraId) async {
    final response = await _dio.get('/api/stream/$cameraId/info');
    return response.data;
  }

  // ==================== System APIs ====================

  Future<Map<String, dynamic>> getHealth() async {
    final response = await _dio.get('/health');
    return response.data;
  }

  Future<Map<String, dynamic>> getConfig() async {
    final response = await _dio.get('/api/config');
    return response.data;
  }
}
