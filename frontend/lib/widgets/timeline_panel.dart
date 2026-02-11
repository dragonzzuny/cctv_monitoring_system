import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Timeline panel showing recent events
class TimelinePanel extends ConsumerStatefulWidget {
  const TimelinePanel({super.key});

  @override
  ConsumerState<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends ConsumerState<TimelinePanel> {
  @override
  void initState() {
    super.initState();
    // Load recent events
    ref.read(eventsProvider.notifier).loadRecentEvents(count: 20);
  }

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
        return 'ROI 진입';
      case 'PPE_HELMET_MISSING':
        return '안전모 미착용';
      case 'PPE_MASK_MISSING':
        return '마스크 미착용';
      case 'FIRE_EXTINGUISHER_MISSING':
        return '소화기 미비치';
      default:
        return eventType;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '방금 전';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else {
      return DateFormat('MM/dd HH:mm').format(dateTime.toLocal());
    }
  }

  Widget _buildStatistics(AsyncValue<List<SafetyEvent>> events) {
    return events.maybeWhen(
      data: (value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _StatChip(label: '미확인', count: value.where((e) => !e.isAcknowledged).length, color: Colors.red),
            const SizedBox(width: 8),
            _StatChip(label: '경고', count: value.where((e) => e.severity == 'WARNING' || e.severity == 'CRITICAL').length, color: Colors.orange),
            const Spacer(),
            if (value.where((e) => !e.isAcknowledged).isNotEmpty)
              TextButton(onPressed: () => ref.read(eventsProvider.notifier).acknowledgeAll(), child: const Text('모두 확인')),
          ],
        ),
      ),
      orElse: () => const SizedBox(),
    );
  }

  Widget _buildEventList(AsyncValue<List<SafetyEvent>> events) {
    return events.when(
      data: (value) => value.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('이벤트가 없습니다', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: value.length,
              itemBuilder: (context, index) {
                final event = value[index];
                return _TimelineEventCard(
                  event: event,
                  severityColor: _getSeverityColor(event.severity),
                  icon: _getEventIcon(event.eventType),
                  typeName: _getEventTypeName(event.eventType),
                  timeText: _formatTime(event.createdAt),
                  onAcknowledge: () => ref.read(eventsProvider.notifier).acknowledgeEvent(event.id),
                );
              },
            ),
      error: (error, stack) => Center(child: Text('오류: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.timeline, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '이벤트 타임라인',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '새로고침',
                  onPressed: () {
                    ref.read(eventsProvider.notifier).loadRecentEvents(count: 20);
                  },
                ),
              ],
            ),
          ),

          // Statistics
          _buildStatistics(events),

          const Divider(height: 1),

          // Event list
          Expanded(
            child: _buildEventList(events),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  final SafetyEvent event;
  final Color severityColor;
  final IconData icon;
  final String typeName;
  final String timeText;
  final VoidCallback onAcknowledge;

  const _TimelineEventCard({
    required this.event,
    required this.severityColor,
    required this.icon,
    required this.typeName,
    required this.timeText,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: event.isAcknowledged
          ? Theme.of(context).cardColor
          : severityColor.withOpacity(0.1),
      child: InkWell(
        onTap: event.isAcknowledged ? null : onAcknowledge,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: severityColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: severityColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.severity,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            typeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const Spacer(),
                        if (!event.isAcknowledged)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: severityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (event.isAcknowledged)
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green[400],
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
    );
  }
}
