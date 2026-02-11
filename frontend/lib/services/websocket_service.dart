import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// WebSocket service for real-time streaming
class WebSocketService {
  final String baseUrl;
  WebSocketChannel? _streamChannel;
  WebSocketChannel? _eventChannel;

  StreamController<StreamFrame>? _frameController;
  StreamController<Map<String, dynamic>>? _eventController;

  bool _isStreamConnected = false;
  bool _isEventConnected = false;
  double _lastTotalDurationMs = 0.0;

  WebSocketService({this.baseUrl = 'ws://localhost:8001'});

  bool get isStreamConnected => _isStreamConnected;
  bool get isEventConnected => _isEventConnected;
  double get lastTotalDurationMs => _lastTotalDurationMs;

  /// Connect to camera stream
  Future<Stream<StreamFrame>> connectToStream(int cameraId) async {
    await disconnectStream();

    _frameController = StreamController<StreamFrame>.broadcast();
    final controller = _frameController!;

    final uri = Uri.parse('$baseUrl/ws/stream/$cameraId');
    _streamChannel = WebSocketChannel.connect(uri);

    _isStreamConnected = true;

    // Capture local ref to prevent stale closure from affecting new connections
    _streamChannel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'frame') {
            // Inject cached totalDuration if frame doesn't have it
            if ((data['total_ms'] == null || data['total_ms'] == 0) && _lastTotalDurationMs > 0) {
              data['total_ms'] = _lastTotalDurationMs;
            }
            final frame = StreamFrame.fromJson(data);
            // Cache totalMs from frame data too
            if (frame.totalMs > 0) {
              _lastTotalDurationMs = frame.totalMs;
            }
            if (!controller.isClosed) {
              controller.add(frame);
            }
          } else if (data['type'] == 'metadata') {
            final durationMs = (data['total_duration_ms'] as num?)?.toDouble() ?? 0.0;
            if (durationMs > 0) {
              _lastTotalDurationMs = durationMs;
              
              // Emit synthetic frame to update totalDuration immediately
              if (!controller.isClosed) {
                controller.add(StreamFrame(
                  cameraId: data['camera_id'] ?? 0,
                  frameBase64: '', // Empty frame
                  currentMs: 0.0,
                  totalMs: durationMs,
                ));
              }
            }
          }
        } catch (e) {
          // parse error ignored
        }
      },
      onError: (error) {
        _isStreamConnected = false;
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        _isStreamConnected = false;
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    return controller.stream;
  }

  /// Send command to stream
  void sendStreamCommand(Map<String, dynamic> command) {
    if (_streamChannel != null && _isStreamConnected) {
      _streamChannel!.sink.add(jsonEncode(command));
    }
  }

  /// Start streaming
  void startStream() {
    sendStreamCommand({'action': 'start'});
  }

  /// Stop streaming
  void stopStream() {
    sendStreamCommand({'action': 'stop'});
  }

  /// Seek to position
  void seekStream(int positionMs) {
    sendStreamCommand({'action': 'seek', 'position_ms': positionMs});
  }

  /// Reload ROIs
  void reloadRois() {
    sendStreamCommand({'action': 'reload_rois'});
  }

  /// Disconnect stream
  Future<void> disconnectStream() async {
    _isStreamConnected = false;
    try {
      await _streamChannel?.sink.close();
    } catch (_) {
      // Channel may already be closed
    }
    _streamChannel = null;
    _lastTotalDurationMs = 0.0;
    try {
      await _frameController?.close();
    } catch (_) {
      // Controller may already be closed
    }
    _frameController = null;
  }

  /// Connect to event notifications
  Future<Stream<Map<String, dynamic>>> connectToEvents() async {
    await disconnectEvents();

    _eventController = StreamController<Map<String, dynamic>>.broadcast();
    final controller = _eventController!;

    final uri = Uri.parse('$baseUrl/ws/events');
    _eventChannel = WebSocketChannel.connect(uri);

    _isEventConnected = true;

    _eventChannel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (!controller.isClosed) {
            controller.add(data);
          }
        } catch (e) {
          // parse error ignored
        }
      },
      onError: (error) {
        _isEventConnected = false;
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        _isEventConnected = false;
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    return controller.stream;
  }

  /// Acknowledge event via WebSocket
  void acknowledgeEvent(int eventId) {
    if (_eventChannel != null && _isEventConnected) {
      _eventChannel!.sink.add(jsonEncode({
        'action': 'acknowledge',
        'event_id': eventId,
      }));
    }
  }

  /// Disconnect events
  Future<void> disconnectEvents() async {
    _isEventConnected = false;
    try {
      await _eventChannel?.sink.close();
    } catch (_) {
      // Channel may already be closed
    }
    _eventChannel = null;
    try {
      await _eventController?.close();
    } catch (_) {
      // Controller may already be closed
    }
    _eventController = null;
  }

  /// Disconnect all
  Future<void> dispose() async {
    await disconnectStream();
    await disconnectEvents();
  }
}
