import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Status bar at the bottom of the screen
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamState = ref.watch(streamProvider);
    final camera = ref.watch(selectedCameraProvider);
    final events = ref.watch(eventsProvider);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Connection status
          _StatusIndicator(
            icon: streamState.isConnected ? Icons.link : Icons.link_off,
            text: streamState.isConnected ? '연결됨' : '연결 안됨',
            color: streamState.isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),

          // Camera info
          if (camera != null) ...[
            _StatusIndicator(
              icon: Icons.videocam,
              text: camera.name,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
          ],

          // Stream status
          if (streamState.isPlaying) ...[
            _StatusIndicator(
              icon: Icons.play_arrow,
              text: '재생 중',
              color: Colors.green,
            ),
            const SizedBox(width: 16),
          ],

          // Detection info
          if (streamState.currentFrame?.detection != null) ...[
            _StatusIndicator(
              icon: Icons.person,
              text: '${streamState.currentFrame!.detection!.personsCount}명 감지',
              color: Colors.orange,
            ),
            const SizedBox(width: 16),
          ],

          const Spacer(),

          // Unacknowledged events
          _buildEventStatus(events),

          const SizedBox(width: 16),

          // Keyboard shortcuts hint
          Text(
            'Space: 재생/일시정지 | Esc: 팝업 닫기',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventStatus(AsyncValue<List<SafetyEvent>> events) {
    return switch (events) {
      AsyncData(:final value) => () {
        final unack = value.where((e) => !e.isAcknowledged).length;
        if (unack > 0) {
          return _StatusIndicator(icon: Icons.warning, text: '미확인 이벤트: $unack건', color: Colors.orange);
        }
        return _StatusIndicator(icon: Icons.check_circle, text: '모든 이벤트 확인됨', color: Colors.green);
      }(),
      _ => const SizedBox(),
    };
  }
}

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusIndicator({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
