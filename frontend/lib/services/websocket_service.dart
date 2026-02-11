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

  WebSocketService({this.baseUrl = 'ws://localhost:8001'});

  bool get isStreamConnected => _isStreamConnected;
  bool get isEventConnected => _isEventConnected;

  /// Connect to camera stream
  Future<Stream<StreamFrame>> connectToStream(int cameraId) async {
    await disconnectStream();

    _frameController = StreamController<StreamFrame>.broadcast();

    final uri = Uri.parse('$baseUrl/ws/stream/$cameraId');
    _streamChannel = WebSocketChannel.connect(uri);

    _isStreamConnected = true;

    _streamChannel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'frame') {
            final frame = StreamFrame.fromJson(data);
            _frameController?.add(frame);
          }
        } catch (e) {
          // parse error ignored
        }
      },
      onError: (error) {
        // stream error
        _isStreamConnected = false;
        _frameController?.addError(error);
      },
      onDone: () {
        // stream closed
        _isStreamConnected = false;
        _frameController?.close();
      },
    );

    return _frameController!.stream;
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

    final uri = Uri.parse('$baseUrl/ws/events');
    _eventChannel = WebSocketChannel.connect(uri);

    _isEventConnected = true;

    _eventChannel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          _eventController?.add(data);
        } catch (e) {
          // parse error ignored
        }
      },
      onError: (error) {
        // event ws error
        _isEventConnected = false;
        _eventController?.addError(error);
      },
      onDone: () {
        // event ws closed
        _isEventConnected = false;
        _eventController?.close();
      },
    );

    return _eventController!.stream;
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
