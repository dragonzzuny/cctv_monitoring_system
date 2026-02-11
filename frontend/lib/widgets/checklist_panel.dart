import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Checklist panel for safety verification
class ChecklistPanel extends ConsumerWidget {
  const ChecklistPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklists = ref.watch(checklistProvider);
    final selectedCamera = ref.watch(selectedCameraProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor),
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
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
                const Icon(Icons.checklist, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '안전 체크리스트',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (selectedCamera != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '체크리스트 새로고침',
                    onPressed: () {
                      ref.read(checklistProvider.notifier).loadChecklists();
                    },
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: selectedCamera == null
                ? const Center(
                    child: Text(
                      '카메라를 선택하세요',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _buildChecklistContent(context, ref, checklists),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistContent(BuildContext context, WidgetRef ref, AsyncValue<List<Checklist>> checklists) {
    return checklists.when(
      data: (value) => _buildChecklistData(context, ref, value),
      error: (error, stack) => Center(child: Text('오류: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildChecklistData(BuildContext context, WidgetRef ref, List<Checklist> checklistList) {
    if (checklistList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('체크리스트가 없습니다', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(checklistProvider.notifier).createDefaultChecklist(),
              icon: const Icon(Icons.add),
              label: const Text('기본 체크리스트 생성'),
            ),
          ],
        ),
      );
    }

    final checklist = checklistList.first;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${checklist.checkedCount}/${checklist.totalCount} 완료',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${(checklist.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: _getProgressColor(checklist.progress), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: checklist.progress,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(checklist.progress)),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: checklist.items.length,
            itemBuilder: (context, index) {
              final item = checklist.items[index];
              return _ChecklistItemCard(
                item: item,
                onChanged: (checked) => ref.read(checklistProvider.notifier).updateItem(item.id, checked),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => ref.read(checklistProvider.notifier).resetChecklist(checklist.id),
            icon: const Icon(Icons.restart_alt),
            label: const Text('초기화'),
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) {
      return Colors.green;
    } else if (progress >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

class _ChecklistItemCard extends StatelessWidget {
  final dynamic item;
  final Function(bool) onChanged;

  const _ChecklistItemCard({
    required this.item,
    required this.onChanged,
  });

  IconData _getItemIcon(String itemType) {
    switch (itemType) {
      case 'PPE_HELMET':
        return Icons.construction;
      case 'PPE_MASK':
        return Icons.masks;
      case 'FIRE_EXTINGUISHER':
        return Icons.local_fire_department;
      case 'ROI_CLEAR':
        return Icons.crop_free;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _getItemColor(String itemType, bool isChecked) {
    if (!isChecked) return Colors.grey;

    switch (itemType) {
      case 'PPE_HELMET':
        return Colors.orange;
      case 'PPE_MASK':
        return Colors.purple;
      case 'FIRE_EXTINGUISHER':
        return Colors.red;
      case 'ROI_CLEAR':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: item.isChecked
          ? Colors.green.withOpacity(0.1)
          : Theme.of(context).cardColor,
      child: InkWell(
        onTap: () => onChanged(!item.isChecked),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getItemColor(item.itemType, item.isChecked)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getItemIcon(item.itemType),
                  color: _getItemColor(item.itemType, item.isChecked),
                ),
              ),
              const SizedBox(width: 12),

              // Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (item.autoChecked)
                      const Text(
                        '자동 확인됨',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),

              // Checkbox
              Checkbox(
                value: item.isChecked,
                onChanged: (value) => onChanged(value ?? false),
                activeColor: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
