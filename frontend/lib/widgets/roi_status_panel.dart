import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../style_constants.dart';

/// Panel showing real-time ROI zone status (person count, stay time)
class RoiStatusPanel extends ConsumerWidget {
  const RoiStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamState = ref.watch(streamProvider);
    final frame = streamState.currentFrame;

    final rois = frame?.rois ?? [];
    final metrics = frame?.roiMetrics ?? {};

    // Build roi name/color lookup
    final roiInfo = <String, Map<String, dynamic>>{};
    for (final roi in rois) {
      final id = roi['id']?.toString() ?? '';
      roiInfo[id] = roi;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  '구역 현황',
                  style: TextStyle(color: AppColors.textMain, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (metrics.isNotEmpty)
                  _buildTotalBadge(metrics),
              ],
            ),
          ),

          // Content
          Expanded(
            child: metrics.isEmpty
                ? const Center(
                    child: Text('설정된 구역이 없습니다', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: metrics.entries.map((entry) {
                      final roiIdStr = entry.key;
                      final m = entry.value as Map<String, dynamic>;
                      final roi = roiInfo[roiIdStr];
                      return _RoiStatusCard(
                        name: roi?['name'] ?? 'ROI $roiIdStr',
                        colorHex: roi?['color'] ?? '#FFFFFF',
                        zoneType: m['zone_type'] ?? 'warning',
                        count: m['count'] ?? 0,
                        people: (m['people'] as List?) ?? [],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBadge(Map<String, dynamic> metrics) {
    int total = 0;
    metrics.forEach((_, m) {
      if (m is Map) total += (m['count'] as int? ?? 0);
    });
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: total > 0 ? AppColors.warning.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '총 $total명',
        style: TextStyle(
          color: total > 0 ? AppColors.warning : AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RoiStatusCard extends StatelessWidget {
  final String name;
  final String colorHex;
  final String zoneType;
  final int count;
  final List<dynamic> people;

  const _RoiStatusCard({
    required this.name,
    required this.colorHex,
    required this.zoneType,
    required this.count,
    required this.people,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _formatStayTime(double seconds) {
    if (seconds < 60) return '${seconds.toInt()}초';
    final min = (seconds / 60).floor();
    final sec = (seconds % 60).toInt();
    return '$min분 $sec초';
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _hexToColor(colorHex);
    final isDanger = zoneType == 'danger';
    final zoneColor = isDanger ? AppColors.danger : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: count > 0 ? zoneColor.withOpacity(0.08) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: count > 0 ? zoneColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone header
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: AppColors.textMain, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: zoneColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isDanger ? '위험' : '경고',
                  style: TextStyle(color: zoneColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count명',
                style: TextStyle(
                  color: count > 0 ? zoneColor : AppColors.textDim,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Person stay times
          if (people.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: people.map<Widget>((p) {
                final stayTime = (p['stay_time'] as num?)?.toDouble() ?? 0.0;
                final isLong = stayTime > 300; // 5min+
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLong ? AppColors.danger.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${p['track_id']} ${_formatStayTime(stayTime)}',
                    style: TextStyle(
                      color: isLong ? AppColors.danger : AppColors.textDim,
                      fontSize: 10,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
