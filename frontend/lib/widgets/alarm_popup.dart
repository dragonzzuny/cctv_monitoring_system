import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Alarm popup overlay for critical events
class AlarmPopup extends ConsumerWidget {
  final SafetyEvent event;

  const AlarmPopup({
    super.key,
    required this.event,
  });

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
      default:
        return Colors.green;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'ROI_INTRUSION':
        return Icons.directions_walk;
      case 'PPE_HELMET_MISSING':
        return Icons.construction;
      case 'PPE_MASK_MISSING':
        return Icons.masks;
      case 'FIRE_EXTINGUISHER_MISSING':
        return Icons.local_fire_department;
      default:
        return Icons.warning;
    }
  }

  String _getEventTypeName(String eventType) {
    switch (eventType) {
      case 'ROI_INTRUSION':
        return 'ROI 진입 감지';
      case 'PPE_HELMET_MISSING':
        return '안전모 미착용 감지';
      case 'PPE_MASK_MISSING':
        return '마스크 미착용 감지';
      case 'FIRE_EXTINGUISHER_MISSING':
        return '소화기 미비치 감지';
      default:
        return eventType;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getSeverityColor(event.severity);

    return Stack(
      children: [
        // Semi-transparent background
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              ref.read(activeAlarmProvider.notifier).hideAlarm();
            },
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),

        // Popup
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 450,
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        topRight: Radius.circular(13),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getEventIcon(event.eventType),
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.severity,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getEventTypeName(event.eventType),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            ref.read(activeAlarmProvider.notifier).hideAlarm();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: color, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.message,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Details
                        _DetailRow('카메라 ID', event.cameraId.toString()),
                        if (event.roiId != null)
                          _DetailRow('ROI ID', event.roiId.toString()),
                        _DetailRow(
                          '발생 시간',
                          _formatDateTime(event.createdAt),
                        ),

                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ref.read(activeAlarmProvider.notifier).hideAlarm();
                                },
                                icon: const Icon(Icons.close),
                                label: const Text('닫기'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(eventsProvider.notifier)
                                      .acknowledgeEvent(event.id);
                                  ref.read(activeAlarmProvider.notifier).hideAlarm();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text(
                                  '확인',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
