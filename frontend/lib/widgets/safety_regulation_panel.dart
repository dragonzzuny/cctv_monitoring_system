import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../style_constants.dart';
import '../services/services.dart';

class SafetyRegulationPanel extends ConsumerWidget {
  const SafetyRegulationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: We'd need a provider for regulations, implementing it briefly here
    return Container(
      decoration: AppStyles.glassDecoration(opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('안전 관련 법령 및 수칙', style: AppStyles.cardTitle),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: const [
                _RegulationCard(
                  category: '산업안전보건법',
                  title: '제38조(안전조치)',
                  content: '사업주는 추락, 붕괴, 전기, 기계·기구 등에 의한 위험을 예방하기 위하여 필요한 조치를 하여야 한다.',
                ),
                _RegulationCard(
                  category: '산업안전보건법',
                  title: '제6조(근로자의 의무)',
                  content: '근로자는 이 법과 이 법에 따른 명령으로 정하는 기준 등 산업재해 예방에 필요한 사항을 지켜야 한다.',
                ),
                _RegulationCard(
                  category: '중대재해처벌법',
                  title: '제4조(확보의무)',
                  content: '사업주 또는 경영책임자 등은 종사자의 안전·보건상 유해 또는 위험을 방지하기 위한 조치를 취해야 한다.',
                ),
                _RegulationCard(
                  category: '안전수칙',
                  title: '개인보호구 착용',
                  content: '현장 내 모든 근로자는 안전모, 안전화 등 필수 보호구를 상시 착용해야 한다.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegulationCard extends StatelessWidget {
  final String category;
  final String title;
  final String content;

  const _RegulationCard({
    required this.category,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  category,
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppStyles.body.copyWith(fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
