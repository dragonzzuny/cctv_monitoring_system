import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'camera_provider.dart';
import 'event_provider.dart';

/// Stream state
class StreamState {
  final bool isConnected;
  final bool isPlaying;
  final double currentPosition;
  final double totalDuration;
  final StreamFrame? currentFrame;
  final String? error;

  StreamState({
    this.isConnected = false,
    this.isPlaying = false,
    this.currentPosition = 0.0,
    this.totalDuration = 0.0,
    this.currentFrame,
    this.error,
  });

  StreamState copyWith({
    bool? isConnected,
    bool? isPlaying,
    double? currentPosition,
    double? totalDuration,
    StreamFrame? currentFrame,
    String? error,
  }) {
    return StreamState(
      isConnected: isConnected ?? this.isConnected,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      currentFrame: currentFrame ?? this.currentFrame,
      error: error,
    );
  }
}

/// Stream notifier
class StreamNotifier extends StateNotifier<StreamState> {
  final WebSocketService _ws;
  final Ref _ref;
  StreamSubscription? _subscription;

  StreamNotifier(this._ws, this._ref) : super(StreamState());

  Future<void> connect(int cameraId) async {
    try {
      // Clean up previous connection before reconnecting
      _subscription?.cancel();
      _subscription = null;
      await _ws.disconnectStream();

      state = state.copyWith(error: null);
      final stream = await _ws.connectToStream(cameraId);

      _subscription = stream.listen(
        (frame) {
          state = state.copyWith(
            isConnected: true,
            currentFrame: frame,
            currentPosition: frame.currentMs,
            totalDuration: frame.totalMs > 0 ? frame.totalMs : state.totalDuration,
          );

          // Process events
          for (final eventData in frame.events) {
            if (eventData.containsKey('id')) {
              try {
                final event = SafetyEvent.fromJson(eventData);
                _ref.read(eventsProvider.notifier).addEvent(event);

                // Show alarm popup for warning/critical
                if (event.severity != 'INFO') {
                  _ref.read(activeAlarmProvider.notifier).showAlarm(event);
                }
              } catch (e) {
                // event parse error ignored
              }
            }
          }
        },
        onError: (error) {
          state = state.copyWith(
            isConnected: false,
            isPlaying: false,
            error: error.toString(),
          );
        },
        onDone: () {
          state = state.copyWith(
            isConnected: false,
            isPlaying: false,
          );
        },
      );

      state = state.copyWith(isConnected: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void startStream() {
    _ws.startStream();
    state = state.copyWith(isPlaying: true);
  }

  void stopStream() {
    _ws.stopStream();
    state = state.copyWith(isPlaying: false);
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      stopStream();
    } else {
      startStream();
    }
  }

  void seek(int positionMs) {
    _ws.seekStream(positionMs);
  }

  void reloadRois() {
    _ws.reloadRois();
  }

  Future<void> disconnect() async {
    _subscription?.cancel();
    await _ws.disconnectStream();
    state = StreamState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ws.disconnectStream();
    super.dispose();
  }
}

/// Stream provider
final streamProvider = StateNotifierProvider<StreamNotifier, StreamState>((ref) {
  final ws = ref.watch(webSocketServiceProvider);
  return StreamNotifier(ws, ref);
});

/// Current frame provider (for easy access to just the frame)
final currentFrameProvider = Provider<StreamFrame?>((ref) {
  return ref.watch(streamProvider).currentFrame;
});

/// Detection result provider
final currentDetectionProvider = Provider<DetectionResult?>((ref) {
  return ref.watch(streamProvider).currentFrame?.detection;
});
