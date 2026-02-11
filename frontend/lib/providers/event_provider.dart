import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'camera_provider.dart';

/// Events state notifier
class EventsNotifier extends StateNotifier<AsyncValue<List<SafetyEvent>>> {
  final ApiService _api;

  EventsNotifier(this._api) : super(const AsyncValue.loading()) {
    loadEvents();
  }

  Future<void> loadEvents({int? cameraId, int limit = 50}) async {
    state = const AsyncValue.loading();
    try {
      final events = await _api.getEvents(cameraId: cameraId, limit: limit);
      state = AsyncValue.data(events);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadRecentEvents({int count = 20, int? cameraId}) async {
    try {
      final events = await _api.getRecentEvents(count: count, cameraId: cameraId);
      state = AsyncValue.data(events);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addEvent(SafetyEvent event) {
    state.whenData((events) {
      state = AsyncValue.data([event, ...events]);
    });
  }

  /// Clear all displayed events from UI (does not delete from DB)
  void clearDisplayedEvents() {
    state = const AsyncValue.data([]);
  }

  Future<void> acknowledgeEvent(int eventId) async {
    await _api.acknowledgeEvent(eventId);
    state.whenData((events) {
      state = AsyncValue.data(events.map((e) {
        if (e.id == eventId) {
          return SafetyEvent(
            id: e.id,
            cameraId: e.cameraId,
            eventType: e.eventType,
            severity: e.severity,
            message: e.message,
            roiId: e.roiId,
            snapshotPath: e.snapshotPath,
            detectionData: e.detectionData,
            isAcknowledged: true,
            acknowledgedAt: DateTime.now(),
            createdAt: e.createdAt,
          );
        }
        return e;
      }).toList());
    });
  }

  Future<void> acknowledgeAll({int? cameraId}) async {
    await _api.acknowledgeAllEvents(cameraId: cameraId);
    await loadEvents(cameraId: cameraId);
  }
}

/// Events provider
final eventsProvider =
    StateNotifierProvider<EventsNotifier, AsyncValue<List<SafetyEvent>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return EventsNotifier(api);
});

/// Unacknowledged events provider
final unacknowledgedEventsProvider =
    FutureProvider<List<SafetyEvent>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getUnacknowledgedEvents();
});

/// Event statistics provider
final eventStatisticsProvider =
    FutureProvider.family<Map<String, dynamic>, int?>((ref, cameraId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getEventStatistics(cameraId: cameraId);
});

/// Active alarm state (for popup display)
class ActiveAlarmState {
  final SafetyEvent? currentAlarm;
  final bool isVisible;

  ActiveAlarmState({this.currentAlarm, this.isVisible = false});
}

/// Active alarm notifier
class ActiveAlarmNotifier extends StateNotifier<ActiveAlarmState> {
  ActiveAlarmNotifier() : super(ActiveAlarmState());

  void showAlarm(SafetyEvent event) {
    state = ActiveAlarmState(currentAlarm: event, isVisible: true);
  }

  void hideAlarm() {
    state = ActiveAlarmState(currentAlarm: state.currentAlarm, isVisible: false);
  }

  void clearAlarm() {
    state = ActiveAlarmState();
  }
}

/// Active alarm provider
final activeAlarmProvider =
    StateNotifierProvider<ActiveAlarmNotifier, ActiveAlarmState>((ref) {
  return ActiveAlarmNotifier();
});
