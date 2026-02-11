import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Event history screen for viewing and filtering past events
class EventHistoryScreen extends ConsumerStatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  ConsumerState<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends ConsumerState<EventHistoryScreen> {
  String? _selectedSeverity;
  String? _selectedEventType;
  bool? _acknowledgedFilter;

  @override
  void initState() {
    super.initState();
    ref.read(eventsProvider.notifier).loadEvents();
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

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('이벤트 이력'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              ref.read(eventsProvider.notifier).loadEvents();
            },
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: '모두 확인',
            onPressed: () async {
              await ref.read(eventsProvider.notifier).acknowledgeAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 이벤트가 확인되었습니다.')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Text('필터: '),
                const SizedBox(width: 16),
                // Severity filter
                DropdownButton<String?>(
                  value: _selectedSeverity,
                  hint: const Text('심각도'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    const DropdownMenuItem(value: 'INFO', child: Text('정보')),
                    const DropdownMenuItem(value: 'WARNING', child: Text('경고')),
                    const DropdownMenuItem(value: 'CRITICAL', child: Text('위험')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSeverity = value;
                    });
                  },
                ),
                const SizedBox(width: 16),
                // Event type filter
                DropdownButton<String?>(
                  value: _selectedEventType,
                  hint: const Text('이벤트 유형'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    const DropdownMenuItem(
                      value: 'ROI_INTRUSION',
                      child: Text('ROI 진입'),
                    ),
                    const DropdownMenuItem(
                      value: 'PPE_HELMET_MISSING',
                      child: Text('안전모 미착용'),
                    ),
                    const DropdownMenuItem(
                      value: 'PPE_MASK_MISSING',
                      child: Text('마스크 미착용'),
                    ),
                    const DropdownMenuItem(
                      value: 'FIRE_EXTINGUISHER_MISSING',
                      child: Text('소화기 미비치'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedEventType = value;
                    });
                  },
                ),
                const SizedBox(width: 16),
                // Acknowledged filter
                DropdownButton<bool?>(
                  value: _acknowledgedFilter,
                  hint: const Text('확인 여부'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('전체')),
                    DropdownMenuItem(value: false, child: Text('미확인')),
                    DropdownMenuItem(value: true, child: Text('확인됨')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _acknowledgedFilter = value;
                    });
                  },
                ),
                const Spacer(),
                // Statistics
                _buildStatistics(events),
              ],
            ),
          ),
          // Event list
          Expanded(
            child: _buildEventList(events, dateFormat),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(AsyncValue<List<SafetyEvent>> events) {
    return events.maybeWhen(
      data: (value) => Text(
        '총 ${value.length}건 (미확인: ${value.where((e) => !e.isAcknowledged).length}건)',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      orElse: () => const SizedBox(),
    );
  }

  Widget _buildEventList(AsyncValue<List<SafetyEvent>> events, DateFormat dateFormat) {
    return events.when(
      data: (value) => _buildFilteredEventList(value, dateFormat),
      error: (error, stack) => Center(child: Text('오류: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildFilteredEventList(List<SafetyEvent> eventList, DateFormat dateFormat) {
    var filtered = eventList;
    if (_selectedSeverity != null) {
      filtered = filtered.where((e) => e.severity == _selectedSeverity).toList();
    }
    if (_selectedEventType != null) {
      filtered = filtered.where((e) => e.eventType == _selectedEventType).toList();
    }
    if (_acknowledgedFilter != null) {
      filtered = filtered.where((e) => e.isAcknowledged == _acknowledgedFilter).toList();
    }

    if (filtered.isEmpty) {
      return const Center(child: Text('이벤트가 없습니다.'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final event = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getSeverityColor(event.severity).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getEventIcon(event.eventType),
                color: _getSeverityColor(event.severity),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(event.severity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.severity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_getEventTypeName(event.eventType)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(event.message),
                Text(
                  dateFormat.format(event.createdAt.toLocal()),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            trailing: event.isAcknowledged
                ? const Icon(Icons.check_circle, color: Colors.green)
                : TextButton(
                    onPressed: () => ref.read(eventsProvider.notifier).acknowledgeEvent(event.id),
                    child: const Text('확인'),
                  ),
            onTap: () => _showEventDetails(context, event),
          ),
        );
      },
    );
  }

  void _showEventDetails(BuildContext context, SafetyEvent event) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getEventIcon(event.eventType),
              color: _getSeverityColor(event.severity),
            ),
            const SizedBox(width: 8),
            Text(_getEventTypeName(event.eventType)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('심각도', event.severity),
              _detailRow('메시지', event.message),
              _detailRow('카메라 ID', event.cameraId.toString()),
              if (event.roiId != null)
                _detailRow('ROI ID', event.roiId.toString()),
              _detailRow('발생 시간', dateFormat.format(event.createdAt.toLocal())),
              _detailRow('확인 여부', event.isAcknowledged ? '확인됨' : '미확인'),
              if (event.acknowledgedAt != null)
                _detailRow(
                  '확인 시간',
                  dateFormat.format(event.acknowledgedAt!.toLocal()),
                ),
              if (event.snapshotPath != null)
                _detailRow('스냅샷', event.snapshotPath!),
            ],
          ),
        ),
        actions: [
          if (!event.isAcknowledged)
            TextButton(
              onPressed: () {
                ref.read(eventsProvider.notifier).acknowledgeEvent(event.id);
                Navigator.pop(context);
              },
              child: const Text('확인 처리'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
