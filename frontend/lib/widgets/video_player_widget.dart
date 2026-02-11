import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../style_constants.dart';
import 'detection_overlay.dart';

/// Video player widget that displays WebSocket stream with seeking support
class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({super.key});

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  Uint8List? _currentFrameBytes;
  bool _isSeeking = false;
  double _seekValue = 0.0;
  int? _connectedCameraId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToCamera();
    });
  }

  void _connectToCamera() {
    final camera = ref.read(selectedCameraProvider);
    if (camera != null && camera.id != _connectedCameraId) {
      _connectedCameraId = camera.id;
      _currentFrameBytes = null;
      ref.read(streamProvider.notifier).connect(camera.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(streamProvider);
    final camera = ref.watch(selectedCameraProvider);

    // Reconnect when selected camera changes
    if (camera != null && camera.id != _connectedCameraId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connectToCamera();
      });
    }

    // Update frame bytes when new frame arrives
    if (streamState.currentFrame != null) {
      try {
        _currentFrameBytes = base64Decode(streamState.currentFrame!.frameBase64);
      } catch (e) {
        // Invalid base64
      }
    }

    final bool isFileSource = camera?.sourceType == 'file';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Video display
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video frame
                if (_currentFrameBytes != null)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: Image.memory(
                        _currentFrameBytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  )
                else if (!streamState.isConnected)
                  _buildConnectionError(streamState, camera)
                else
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),

                // Detection overlay summary
                if (streamState.currentFrame?.detection != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: AppStyles.glassDecoration(opacity: 0.2),
                      child: DetectionInfoOverlay(
                        detection: streamState.currentFrame!.detection!,
                        roiMetrics: streamState.currentFrame!.roiMetrics,
                      ),
                    ),
                  ),

                // Premium Status Indicator
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: AppStyles.glassDecoration(
                      opacity: 0.2,
                      color: streamState.isConnected ? AppColors.success : AppColors.danger,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          streamState.isConnected ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          streamState.isConnected ? 'LIVE' : 'OFFLINE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress Bar for File Sources
          if (isFileSource && streamState.isConnected)
            _buildProgressBar(streamState),

          // Premium Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Play/Pause button
                _buildActionButton(
                  icon: streamState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onPressed: !streamState.isConnected
                      ? null
                      : () => ref.read(streamProvider.notifier).togglePlayPause(),
                  color: AppColors.primary,
                ),

                const SizedBox(width: 8),

                // Stop button
                _buildActionButton(
                  icon: Icons.stop_rounded,
                  onPressed: !streamState.isPlaying
                      ? null
                      : () => ref.read(streamProvider.notifier).stopStream(),
                  color: AppColors.danger,
                ),

                const SizedBox(width: 20),

                // Camera info
                if (camera != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name,
                          style: AppStyles.cardTitle.copyWith(fontSize: 14),
                        ),
                        Text(
                          camera.sourceType.toUpperCase(),
                          style: AppStyles.body.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                // Reload ROIs button
                _buildActionButton(
                  icon: Icons.refresh_rounded,
                  onPressed: !streamState.isConnected
                      ? null
                      : () => ref.read(streamProvider.notifier).reloadRois(),
                  size: 20,
                  padding: 8,
                ),

                const SizedBox(width: 8),

                // Connection button
                _buildActionButton(
                  icon: streamState.isConnected ? Icons.link_off_rounded : Icons.link_rounded,
                  onPressed: () {
                    if (camera != null) {
                      if (streamState.isConnected) {
                        ref.read(streamProvider.notifier).disconnect();
                      } else {
                        ref.read(streamProvider.notifier).connect(camera.id);
                      }
                    }
                  },
                  color: streamState.isConnected ? AppColors.warning : AppColors.success,
                  size: 20,
                  padding: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(StreamState streamState) {
    // Note: We'd ideally need total_frames/duration from backend
    // Assuming 0.0 - 1.0 for now if duration isn't clearly exposed in streamState
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: AppColors.primary,
            ),
            child: Slider(
              value: _isSeeking ? _seekValue : _calculateProgress(streamState),
              onChanged: (value) {
                setState(() {
                  _isSeeking = true;
                  _seekValue = value;
                });
              },
              onChangeEnd: (value) {
                _handleSeek(value);
                setState(() {
                  _isSeeking = false;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(streamState.currentPosition),
                  style: AppStyles.body.copyWith(fontSize: 10, color: Colors.white70),
                ),
                Text(
                  _formatDuration(streamState.totalDuration),
                  style: AppStyles.body.copyWith(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double ms) {
    if (ms <= 0) return "00:00";
    final duration = Duration(milliseconds: ms.toInt());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  double _calculateProgress(StreamState state) {
    double duration = state.totalDuration;
    if (duration <= 0) {
      duration = ref.read(webSocketServiceProvider).lastTotalDurationMs;
    }
    
    if (duration <= 0) return 0.0;
    final progress = state.currentPosition / duration;
    return progress.clamp(0.0, 1.0);
  }

  void _handleSeek(double value) {
    final streamState = ref.read(streamProvider);
    double duration = streamState.totalDuration;

    // Fallback: get cached duration from WebSocket metadata
    if (duration <= 0) {
      duration = ref.read(webSocketServiceProvider).lastTotalDurationMs;
    }

    if (duration > 0) {
      final targetMs = (value * duration).toInt();
      ref.read(streamProvider.notifier).seek(targetMs);
      // Update frame bytes to null so old frame doesn't linger
      setState(() {
        _currentFrameBytes = null;
      });
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onPressed,
    Color color = Colors.white,
    double size = 28,
    double padding = 10,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: onPressed == null ? Colors.grey : color, size: size),
        ),
      ),
    );
  }

  Widget _buildConnectionError(StreamState streamState, dynamic camera) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: AppStyles.glassDecoration(opacity: 0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              streamState.error ?? '연결 대기 중입니다.',
              style: AppStyles.body,
              textAlign: TextAlign.center,
            ),
            if (camera != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  ref.read(streamProvider.notifier).connect(camera.id);
                },
                child: const Text('서버에 재연결 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
