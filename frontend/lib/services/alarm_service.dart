import 'package:audioplayers/audioplayers.dart';
import '../models/event.dart';

/// Alarm service for playing alert sounds
class AlarmService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  /// Play alarm sound based on severity
  Future<void> playAlarm(Severity severity) async {
    if (_isMuted) return;

    try {
      String soundFile;
      switch (severity) {
        case Severity.critical:
          soundFile = 'sounds/alarm_critical.wav';
          break;
        case Severity.warning:
          soundFile = 'sounds/alarm_warning.wav';
          break;
        case Severity.info:
          soundFile = 'sounds/alarm_info.wav';
          break;
      }

      await _audioPlayer.play(AssetSource(soundFile));
    } catch (e) {
      // Sound file may not exist, use system beep
      // fallback: sound file missing
    }
  }

  /// Play simple notification sound
  Future<void> playNotification() async {
    if (_isMuted) return;

    try {
      await _audioPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      // fallback: sound file missing
    }
  }

  /// Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
  }

  /// Set mute state
  void setMute(bool muted) {
    _isMuted = muted;
  }

  /// Stop playing
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Dispose
  void dispose() {
    _audioPlayer.dispose();
  }
}
