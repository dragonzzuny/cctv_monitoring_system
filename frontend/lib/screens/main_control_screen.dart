import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../widgets/safety_regulation_panel.dart';
import '../style_constants.dart';
import 'screens.dart';

/// Main control screen with premium glassmorphism design
class MainControlScreen extends ConsumerStatefulWidget {
  const MainControlScreen({super.key});

  @override
  ConsumerState<MainControlScreen> createState() => _MainControlScreenState();
}

class _MainControlScreenState extends ConsumerState<MainControlScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final streamNotifier = ref.read(streamProvider.notifier);

      switch (event.logicalKey) {
        case LogicalKeyboardKey.space:
          streamNotifier.togglePlayPause();
          break;
        case LogicalKeyboardKey.escape:
          ref.read(activeAlarmProvider.notifier).hideAlarm();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameras = ref.watch(camerasProvider);
    final selectedCamera = ref.watch(selectedCameraProvider);
    final activeAlarm = ref.watch(activeAlarmProvider);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context, cameras, selectedCamera),
        body: Stack(
          children: [
            // Industrial background decoration (simulated)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.05),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Video & Regulations
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        // Video Player Section
                        Expanded(
                          flex: 3,
                          child: selectedCamera == null
                              ? _buildEmptyState()
                              : const VideoPlayerWidget(),
                        ),
                        const SizedBox(height: 16),
                        // Safety Regulations Section
                        const Expanded(
                          flex: 1,
                          child: SafetyRegulationPanel(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Right Column: ROI Status, Checklist, Timeline
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // ROI Zone Status Panel
                        if (selectedCamera != null)
                          const SizedBox(
                            height: 180,
                            child: RoiStatusPanel(),
                          ),
                        if (selectedCamera != null)
                          const SizedBox(height: 12),
                        // Checklist Panel
                        const Expanded(
                          child: ChecklistPanel(),
                        ),
                        const SizedBox(height: 12),
                        // Timeline Panel
                        const Expanded(
                          child: TimelinePanel(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Alarm popup overlay
            if (activeAlarm.isVisible && activeAlarm.currentAlarm != null)
              AlarmPopup(event: activeAlarm.currentAlarm!),
          ],
        ),
        bottomNavigationBar: const StatusBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, dynamic cameras, dynamic selectedCamera) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.security_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CCTV SAFE-YOLO', style: AppStyles.heading.copyWith(fontSize: 18)),
              Text('INDUSTRIAL MONITORING v1.0', style: AppStyles.body.copyWith(fontSize: 10, letterSpacing: 1)),
            ],
          ),
          const Spacer(),
          // Custom Styled Camera Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: AppStyles.glassDecoration(borderRadius: 12),
            child: _buildCameraSelector(cameras, selectedCamera),
          ),
          const SizedBox(width: 16),
          // Tool Header Buttons
          _buildHeaderButton(Icons.settings_outlined, '설정', () => Navigator.pushNamed(context, '/settings')),
          _buildHeaderButton(Icons.crop_free_rounded, 'ROI', selectedCamera == null ? null : () => Navigator.pushNamed(context, '/roi_editor')),
          _buildHeaderButton(Icons.history_rounded, '이력', () => Navigator.pushNamed(context, '/history')),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        icon: Icon(icon),
        tooltip: label,
        onPressed: onTap,
        color: onTap == null ? AppColors.textDim : Colors.white,
      ),
    );
  }

  Widget _buildCameraSelector(AsyncValue<List<Camera>> cameras, Camera? selectedCamera) {
    return cameras.when(
      data: (value) => DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedCamera?.id,
          dropdownColor: AppColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
          hint: Text('카메라 선택', style: AppStyles.body),
          style: AppStyles.cardTitle.copyWith(fontSize: 14),
          items: value.map((camera) {
            return DropdownMenuItem<int>(
              value: camera.id,
              child: Text(camera.name),
            );
          }).toList(),
          onChanged: (cameraId) {
            if (cameraId != null) {
              final camera = value.firstWhere((c) => c.id == cameraId);
              ref.read(selectedCameraProvider.notifier).state = camera;
              // VideoPlayerWidget handles connection via camera change detection
            }
          },
        ),
      ),
      error: (error, stack) => const Icon(Icons.error, color: AppColors.danger),
      loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: AppStyles.glassDecoration(opacity: 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded, size: 80, color: AppColors.textDim.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            '모니터링할 카메라를 상단에서 선택하세요',
            style: AppStyles.body.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
