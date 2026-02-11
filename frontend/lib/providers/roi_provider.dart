import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'camera_provider.dart';

/// ROIs state notifier
class RoisNotifier extends StateNotifier<AsyncValue<List<ROI>>> {
  final ApiService _api;
  final int? _cameraId;

  RoisNotifier(this._api, this._cameraId) : super(const AsyncValue.loading()) {
    if (_cameraId != null) {
      loadRois();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> loadRois() async {
    if (_cameraId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final rois = await _api.getRois(cameraId: _cameraId);
      state = AsyncValue.data(rois);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ROI> addRoi(ROICreate roi) async {
    final newRoi = await _api.createRoi(roi);
    await loadRois();
    return newRoi;
  }

  Future<void> deleteRoi(int roiId) async {
    await _api.deleteRoi(roiId);
    await loadRois();
  }

  Future<ROI> updateRoi(int roiId, Map<String, dynamic> data) async {
    final updatedRoi = await _api.updateRoi(roiId, data);
    await loadRois();
    return updatedRoi;
  }
}

/// ROIs provider (depends on selected camera)
final roisProvider =
    StateNotifierProvider<RoisNotifier, AsyncValue<List<ROI>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  final camera = ref.watch(selectedCameraProvider);
  return RoisNotifier(api, camera?.id);
});

/// ROI editing state
class RoiEditingState {
  final bool isEditing;
  final int? editingRoiId; // null = new ROI, non-null = editing existing
  final List<Point> currentPoints;
  final String currentName;
  final String currentColor;
  final String currentZoneType;

  RoiEditingState({
    this.isEditing = false,
    this.editingRoiId,
    this.currentPoints = const [],
    this.currentName = '',
    this.currentColor = '#FF0000',
    this.currentZoneType = 'warning',
  });

  RoiEditingState copyWith({
    bool? isEditing,
    int? editingRoiId,
    List<Point>? currentPoints,
    String? currentName,
    String? currentColor,
    String? currentZoneType,
  }) {
    return RoiEditingState(
      isEditing: isEditing ?? this.isEditing,
      editingRoiId: editingRoiId ?? this.editingRoiId,
      currentPoints: currentPoints ?? this.currentPoints,
      currentName: currentName ?? this.currentName,
      currentColor: currentColor ?? this.currentColor,
      currentZoneType: currentZoneType ?? this.currentZoneType,
    );
  }
}

/// ROI editing state notifier
class RoiEditingNotifier extends StateNotifier<RoiEditingState> {
  RoiEditingNotifier() : super(RoiEditingState());

  void startEditing() {
    state = RoiEditingState(isEditing: true);
  }

  /// Start editing an existing ROI
  void startEditingRoi(ROI roi) {
    state = RoiEditingState(
      isEditing: true,
      editingRoiId: roi.id,
      currentPoints: List.from(roi.points),
      currentName: roi.name,
      currentColor: roi.color,
      currentZoneType: roi.zoneType,
    );
  }

  void stopEditing() {
    state = RoiEditingState();
  }

  void addPoint(Point point) {
    state = state.copyWith(
      currentPoints: [...state.currentPoints, point],
    );
  }

  void removeLastPoint() {
    if (state.currentPoints.isNotEmpty) {
      state = state.copyWith(
        currentPoints: state.currentPoints.sublist(0, state.currentPoints.length - 1),
      );
    }
  }

  void clearPoints() {
    state = state.copyWith(currentPoints: []);
  }

  void setName(String name) {
    state = state.copyWith(currentName: name);
  }

  void setColor(String color) {
    state = state.copyWith(currentColor: color);
  }
}

/// ROI editing provider
final roiEditingProvider =
    StateNotifierProvider<RoiEditingNotifier, RoiEditingState>((ref) {
  return RoiEditingNotifier();
});
