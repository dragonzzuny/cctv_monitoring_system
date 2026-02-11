import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// API Service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// WebSocket Service provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Cameras state notifier
class CamerasNotifier extends StateNotifier<AsyncValue<List<Camera>>> {
  final ApiService _api;

  CamerasNotifier(this._api) : super(const AsyncValue.loading()) {
    loadCameras();
  }

  Future<void> loadCameras() async {
    state = const AsyncValue.loading();
    try {
      final cameras = await _api.getCameras();
      state = AsyncValue.data(cameras);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Camera> addCamera(CameraCreate camera) async {
    final newCamera = await _api.createCamera(camera);
    await loadCameras();
    return newCamera;
  }

  Future<void> deleteCamera(int cameraId) async {
    await _api.deleteCamera(cameraId);
    await loadCameras();
  }

  Future<Camera> updateCamera(int cameraId, Map<String, dynamic> data) async {
    final updatedCamera = await _api.updateCamera(cameraId, data);
    await loadCameras();
    return updatedCamera;
  }
}

/// Cameras provider
final camerasProvider =
    StateNotifierProvider<CamerasNotifier, AsyncValue<List<Camera>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return CamerasNotifier(api);
});

/// Selected camera provider
final selectedCameraProvider = StateProvider<Camera?>((ref) => null);

/// Camera info provider
final cameraInfoProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, cameraId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getStreamInfo(cameraId);
});
