import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'camera_provider.dart';

/// Checklist state notifier
class ChecklistNotifier extends StateNotifier<AsyncValue<List<Checklist>>> {
  final ApiService _api;
  final int? _cameraId;

  ChecklistNotifier(this._api, this._cameraId) : super(const AsyncValue.loading()) {
    if (_cameraId != null) {
      loadChecklists();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> loadChecklists() async {
    if (_cameraId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final checklists = await _api.getChecklists(cameraId: _cameraId);
      state = AsyncValue.data(checklists);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Checklist> createDefaultChecklist() async {
    if (_cameraId == null) throw Exception('No camera selected');

    final checklist = await _api.createDefaultChecklist(_cameraId);
    await loadChecklists();
    return checklist;
  }

  Future<void> updateItem(int itemId, bool isChecked) async {
    await _api.updateChecklistItem(itemId, isChecked);
    await loadChecklists();
  }

  Future<void> resetChecklist(int checklistId) async {
    await _api.resetChecklist(checklistId);
    await loadChecklists();
  }

  void autoCheckItem(String itemType) {
    state.whenData((checklists) {
      state = AsyncValue.data(checklists.map((checklist) {
        return Checklist(
          id: checklist.id,
          cameraId: checklist.cameraId,
          name: checklist.name,
          isActive: checklist.isActive,
          items: checklist.items.map((item) {
            if (item.itemType == itemType && !item.isChecked) {
              return item.copyWith(isChecked: true, autoChecked: true);
            }
            return item;
          }).toList(),
          createdAt: checklist.createdAt,
          updatedAt: checklist.updatedAt,
        );
      }).toList());
    });
  }
}

/// Checklist provider (depends on selected camera)
final checklistProvider =
    StateNotifierProvider<ChecklistNotifier, AsyncValue<List<Checklist>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  final camera = ref.watch(selectedCameraProvider);
  return ChecklistNotifier(api, camera?.id);
});

/// Current checklist provider (first active checklist for camera)
final currentChecklistProvider = Provider<Checklist?>((ref) {
  final checklists = ref.watch(checklistProvider);
  return checklists.whenOrNull(
    data: (list) => list.isNotEmpty ? list.first : null,
  );
});
