import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Camera settings and management screen
class CameraSettingsScreen extends ConsumerStatefulWidget {
  const CameraSettingsScreen({super.key});

  @override
  ConsumerState<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends ConsumerState<CameraSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sourceController = TextEditingController();
  String _sourceType = 'file';

  @override
  void dispose() {
    _nameController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _addCamera() async {
    if (!_formKey.currentState!.validate()) return;

    final camera = CameraCreate(
      name: _nameController.text,
      source: _sourceController.text,
      sourceType: _sourceType,
    );

    try {
      await ref.read(camerasProvider.notifier).addCamera(camera);
      _nameController.clear();
      _sourceController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라가 추가되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _deleteCamera(Camera camera) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카메라 삭제'),
        content: Text('${camera.name}을(를) 삭제하시겠습니까?\n관련 ROI, 이벤트도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // If the deleted camera is currently selected, disconnect stream first
        final selectedCamera = ref.read(selectedCameraProvider);
        if (selectedCamera != null && selectedCamera.id == camera.id) {
          await ref.read(streamProvider.notifier).disconnect();
          ref.read(selectedCameraProvider.notifier).state = null;
        }

        await ref.read(camerasProvider.notifier).deleteCamera(camera.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${camera.name}이(가) 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  Widget _buildCameraList(AsyncValue<List<Camera>> cameras) {
    return cameras.when(
      data: (value) => value.isEmpty
          ? const Center(child: Text('등록된 카메라가 없습니다.'))
          : ListView.builder(
              itemCount: value.length,
              itemBuilder: (context, index) {
                final camera = value[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      camera.isActive ? Icons.videocam : Icons.videocam_off,
                      color: camera.isActive ? Colors.green : Colors.grey,
                    ),
                    title: Text(camera.name),
                    subtitle: Text(
                      '${camera.sourceType}: ${camera.source}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: camera.isActive,
                          onChanged: (value) {
                            ref.read(camerasProvider.notifier).updateCamera(camera.id, {
                              'is_active': value,
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () => _deleteCamera(camera),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      error: (error, stack) => Center(child: Text('오류: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameras = ref.watch(camerasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카메라 설정'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera list
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '등록된 카메라',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildCameraList(cameras),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Add camera form
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '카메라 추가',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: '카메라 이름',
                            hintText: '예: 현장 카메라 1',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '카메라 이름을 입력하세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _sourceType,
                          decoration: const InputDecoration(
                            labelText: '소스 유형',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'file',
                              child: Text('파일'),
                            ),
                            DropdownMenuItem(
                              value: 'rtsp',
                              child: Text('RTSP 스트림'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _sourceType = value ?? 'file';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _sourceController,
                          decoration: InputDecoration(
                            labelText: _sourceType == 'file'
                                ? '파일 경로'
                                : 'RTSP URL',
                            hintText: _sourceType == 'file'
                                ? 'C:\\Videos\\test.mp4'
                                : 'rtsp://192.168.1.100:554/stream',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '소스 경로를 입력하세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addCamera,
                            icon: const Icon(Icons.add),
                            label: const Text('카메라 추가'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
