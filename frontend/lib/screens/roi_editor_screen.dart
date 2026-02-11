import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// ROI editor screen for drawing and managing ROIs
class RoiEditorScreen extends ConsumerStatefulWidget {
  const RoiEditorScreen({super.key});

  @override
  ConsumerState<RoiEditorScreen> createState() => _RoiEditorScreenState();
}

class _RoiEditorScreenState extends ConsumerState<RoiEditorScreen> {
  final _nameController = TextEditingController();
  String _selectedColor = '#FFFF00'; // Default to yellow for warning
  String _selectedZoneType = 'warning';
  Uint8List? _snapshotBytes;
  Size? _imageSize;

  final List<String> _colors = [
    '#FF0000', // Red
    '#00FF00', // Green
    '#0000FF', // Blue
    '#FFFF00', // Yellow
    '#FF00FF', // Magenta
    '#00FFFF', // Cyan
    '#FFA500', // Orange
  ];

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    final camera = ref.read(selectedCameraProvider);
    if (camera == null) return;

    try {
      final api = ref.read(apiServiceProvider);
      final snapshot = await api.getSnapshot(camera.id, withDetection: false);
      final frameBase64 = snapshot['frame_base64'] as String;
      setState(() {
        _snapshotBytes = base64Decode(frameBase64);
      });
    } catch (e) {
      // snapshot load failed
    }
  }

  Future<void> _saveRoi() async {
    final camera = ref.read(selectedCameraProvider);
    final editingState = ref.read(roiEditingProvider);

    if (camera == null) return;
    if (editingState.currentPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 3개의 점이 필요합니다.')),
      );
      return;
    }
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ROI 이름을 입력하세요.')),
      );
      return;
    }

    try {
      if (editingState.editingRoiId != null) {
        // Update existing ROI
        await ref.read(roisProvider.notifier).updateRoi(
          editingState.editingRoiId!,
          {
            'name': _nameController.text,
            'points': editingState.currentPoints.map((p) => p.toJson()).toList(),
            'color': _selectedColor,
            'zone_type': _selectedZoneType,
          },
        );
      } else {
        // Create new ROI
        final roi = ROICreate(
          cameraId: camera.id,
          name: _nameController.text,
          points: editingState.currentPoints,
          color: _selectedColor,
          zoneType: _selectedZoneType,
        );
        await ref.read(roisProvider.notifier).addRoi(roi);
      }

      ref.read(streamProvider.notifier).reloadRois();
      ref.read(roiEditingProvider.notifier).stopEditing();
      _nameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(editingState.editingRoiId != null ? 'ROI가 수정되었습니다.' : 'ROI가 저장되었습니다.')),
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

  void _startEditRoi(ROI roi) {
    ref.read(roiEditingProvider.notifier).startEditingRoi(roi);
    _nameController.text = roi.name;
    setState(() {
      _selectedColor = roi.color;
      _selectedZoneType = roi.zoneType;
    });
  }

  Future<void> _deleteRoi(ROI roi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ROI 삭제'),
        content: Text('${roi.name}을(를) 삭제하시겠습니까?'),
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
      await ref.read(roisProvider.notifier).deleteRoi(roi.id);
      
      // Signal stream to reload ROIs if active
      ref.read(streamProvider.notifier).reloadRois();
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Widget _buildRoiList(AsyncValue<List<ROI>> rois) {
    return rois.when(
      data: (value) => value.isEmpty
          ? const Center(child: Text('등록된 ROI가 없습니다.'))
          : ListView.builder(
              itemCount: value.length,
              itemBuilder: (context, index) {
                final roi = value[index];
                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _hexToColor(roi.color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text(roi.name),
                    subtitle: Text('${roi.points.length}개 점 | ${roi.zoneType == 'danger' ? '위험' : '경고'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: roi.isActive,
                          onChanged: (value) => ref.read(roisProvider.notifier).updateRoi(roi.id, {'is_active': value}),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: Colors.blue,
                          onPressed: () => _startEditRoi(roi),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () => _deleteRoi(roi),
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
    final camera = ref.watch(selectedCameraProvider);
    final rois = ref.watch(roisProvider);
    final editingState = ref.watch(roiEditingProvider);

    if (camera == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ROI 편집')),
        body: const Center(child: Text('카메라를 선택하세요.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('ROI 편집 - ${camera.name}'),
        actions: [
          if (editingState.isEditing)
            TextButton.icon(
              onPressed: () {
                ref.read(roiEditingProvider.notifier).stopEditing();
                _nameController.clear();
              },
              icon: const Icon(Icons.close),
              label: const Text('취소'),
            ),
          if (!editingState.isEditing)
            TextButton.icon(
              onPressed: () {
                ref.read(roiEditingProvider.notifier).startEditing();
              },
              icon: const Icon(Icons.add),
              label: const Text('새 ROI'),
            ),
        ],
      ),
      body: Row(
        children: [
          // Left: Image with ROI overlay
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: _snapshotBytes == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: editingState.isEditing
                              ? (details) {
                                  final box = context.findRenderObject() as RenderBox;
                                  final localPos = box.globalToLocal(details.globalPosition);

                                  // Get the image dimensions
                                  if (_imageSize == null) return;

                                  // Calculate scale and offset (BoxFit.contain logic)
                                  final scaleX = constraints.maxWidth / _imageSize!.width;
                                  final scaleY = constraints.maxHeight / _imageSize!.height;
                                  final scale = scaleX < scaleY ? scaleX : scaleY;

                                  final offsetX = (constraints.maxWidth - _imageSize!.width * scale) / 2;
                                  final offsetY = (constraints.maxHeight - _imageSize!.height * scale) / 2;

                                  // Convert screen coordinates to image coordinates
                                  double x = (localPos.dx - offsetX) / scale;
                                  double y = (localPos.dy - offsetY) / scale;

                                  // Clamp to image bounds
                                  x = x.clamp(0.0, _imageSize!.width);
                                  y = y.clamp(0.0, _imageSize!.height);

                                  ref.read(roiEditingProvider.notifier).addPoint(Point(x: x, y: y));
                                }
                              : null,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _snapshotBytes!,
                                fit: BoxFit.contain,
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  // frame is non-null when the first frame is available
                                  if (frame != null && _imageSize == null) {
                                    // Get original image size
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      final imageProvider = MemoryImage(_snapshotBytes!);
                                      imageProvider.resolve(const ImageConfiguration()).addListener(
                                        ImageStreamListener((info, _) {
                                          if (mounted) {
                                            setState(() {
                                              _imageSize = Size(
                                                info.image.width.toDouble(),
                                                info.image.height.toDouble(),
                                              );
                                            });
                                          }
                                        }),
                                      );
                                    });
                                  }
                                  return child;
                                },
                              ),
                              // Draw existing ROIs
                              if (_imageSize != null)
                                CustomPaint(
                                  painter: RoiPainter(
                                    rois: rois.asData?.value ?? [],
                                    currentPoints: editingState.currentPoints,
                                    currentColor: _hexToColor(_selectedColor),
                                    imageSize: _imageSize!,
                                    containerSize: Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Right: ROI list and editing controls
          SizedBox(
            width: 320,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (editingState.isEditing) ...[
                      Text(
                        editingState.editingRoiId != null ? 'ROI 수정' : '새 ROI 생성',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'ROI 이름',
                          hintText: '예: 작업구역 A',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('영역 유형'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'warning',
                            label: Text('경고 영역'),
                            icon: Icon(Icons.warning, color: Colors.yellow),
                          ),
                          ButtonSegment(
                            value: 'danger',
                            label: Text('위험 영역'),
                            icon: Icon(Icons.dangerous, color: Colors.red),
                          ),
                        ],
                        selected: {_selectedZoneType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedZoneType = newSelection.first;
                            // Update default color based on zone type
                            if (_selectedZoneType == 'warning') {
                              _selectedColor = '#FFFF00'; // Yellow
                            } else {
                              _selectedColor = '#FF0000'; // Red
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('색상 선택'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _colors.map((color) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _hexToColor(color),
                                border: Border.all(
                                  color: _selectedColor == color
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '점 개수: ${editingState.currentPoints.length}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '이미지를 클릭하여 점을 추가하세요.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: editingState.currentPoints.isEmpty
                                  ? null
                                  : () {
                                      ref.read(roiEditingProvider.notifier)
                                          .removeLastPoint();
                                    },
                              icon: const Icon(Icons.undo),
                              label: const Text('실행취소'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: editingState.currentPoints.isEmpty
                                  ? null
                                  : () {
                                      ref.read(roiEditingProvider.notifier)
                                          .clearPoints();
                                    },
                              icon: const Icon(Icons.clear),
                              label: const Text('초기화'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: editingState.currentPoints.length >= 3
                              ? _saveRoi
                              : null,
                          icon: const Icon(Icons.save),
                          label: Text(editingState.editingRoiId != null ? 'ROI 수정' : 'ROI 저장'),
                        ),
                      ),
                      const Divider(height: 32),
                    ],
                    Text(
                      '저장된 ROI',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildRoiList(rois),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing ROIs on the image
class RoiPainter extends CustomPainter {
  final List<ROI> rois;
  final List<Point> currentPoints;
  final Color currentColor;
  final Size imageSize;
  final Size containerSize;

  RoiPainter({
    required this.rois,
    required this.currentPoints,
    required this.currentColor,
    required this.imageSize,
    required this.containerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale to fit image in container
    final scaleX = containerSize.width / imageSize.width;
    final scaleY = containerSize.height / imageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate offset to center the image
    final offsetX = (containerSize.width - imageSize.width * scale) / 2;
    final offsetY = (containerSize.height - imageSize.height * scale) / 2;

    Offset toScreen(Point p) {
      return Offset(
        p.x * scale + offsetX,
        p.y * scale + offsetY,
      );
    }

    // Draw existing ROIs
    for (final roi in rois) {
      if (roi.points.length < 3) continue;

      final paint = Paint()
        ..color = _hexToColor(roi.color).withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = _hexToColor(roi.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path();
      final first = toScreen(roi.points.first);
      path.moveTo(first.dx, first.dy);

      for (int i = 1; i < roi.points.length; i++) {
        final point = toScreen(roi.points[i]);
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(path, paint);
      canvas.drawPath(path, strokePaint);

      // Draw ROI name
      final textPainter = TextPainter(
        text: TextSpan(
          text: roi.name,
          style: TextStyle(
            color: _hexToColor(roi.color),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final namePos = toScreen(roi.points.first);
      textPainter.paint(canvas, Offset(namePos.dx + 5, namePos.dy - 20));
    }

    // Draw current editing points
    if (currentPoints.isNotEmpty) {
      final pointPaint = Paint()
        ..color = currentColor
        ..style = PaintingStyle.fill;

      final linePaint = Paint()
        ..color = currentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Draw points
      for (final point in currentPoints) {
        final screenPoint = toScreen(point);
        canvas.drawCircle(screenPoint, 6, pointPaint);
      }

      // Draw lines
      if (currentPoints.length > 1) {
        final path = Path();
        final first = toScreen(currentPoints.first);
        path.moveTo(first.dx, first.dy);

        for (int i = 1; i < currentPoints.length; i++) {
          final point = toScreen(currentPoints[i]);
          path.lineTo(point.dx, point.dy);
        }

        // Close path if we have at least 3 points
        if (currentPoints.length >= 3) {
          path.close();

          // Draw fill
          final fillPaint = Paint()
            ..color = currentColor.withOpacity(0.3)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, fillPaint);
        }

        canvas.drawPath(path, linePaint);
      }
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  bool shouldRepaint(covariant RoiPainter oldDelegate) {
    return oldDelegate.rois != rois ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.currentColor != currentColor;
  }
}
