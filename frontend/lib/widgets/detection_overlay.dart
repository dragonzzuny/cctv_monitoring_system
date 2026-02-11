import 'package:flutter/material.dart';
import '../models/models.dart';

/// Detection info overlay showing summary counts
class DetectionInfoOverlay extends StatelessWidget {
  final DetectionResult detection;
  final Map<String, dynamic> roiMetrics;

  const DetectionInfoOverlay({
    super.key,
    required this.detection,
    this.roiMetrics = const {},
  });

  @override
  Widget build(BuildContext context) {
    int warningCount = 0;
    int dangerCount = 0;

    roiMetrics.forEach((_, metrics) {
      final zoneType = metrics['zone_type'] as String;
      final count = metrics['count'] as int;
      if (zoneType == 'danger') {
        dangerCount += count;
      } else {
        warningCount += count;
      }
    });

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(Icons.person, '작업자', detection.personsCount),
          _buildRow(Icons.construction, '안전모', detection.helmetsCount),
          if (warningCount > 0 || dangerCount > 0) ...[
            _buildRow(Icons.warning, '경고구역', warningCount,
                color: warningCount > 0 ? Colors.yellow : Colors.white70),
            _buildRow(Icons.dangerous, '위험구역', dangerCount,
                color: dangerCount > 0 ? Colors.red : Colors.white70),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, int count, {Color? color}) {
    final displayColor = color ?? _getCountColor(label, count);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: displayColor),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              color: displayColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCountColor(String label, int count) {
    if (label == '안전모') {
      if (detection.personsCount > 0 && count >= detection.personsCount) {
        return Colors.green;
      } else if (detection.personsCount > 0 && count > 0) {
        return Colors.orange;
      } else if (detection.personsCount > 0 && count == 0) {
        return Colors.red;
      }
    }
    return Colors.white;
  }
}

/// Full detection overlay with bounding boxes
class DetectionBoxOverlay extends StatelessWidget {
  final List<DetectionBox> detections;
  final Size imageSize;
  final Size displaySize;

  const DetectionBoxOverlay({
    super.key,
    required this.detections,
    required this.imageSize,
    required this.displaySize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: displaySize,
      painter: DetectionBoxPainter(
        detections: detections,
        imageSize: imageSize,
        displaySize: displaySize,
      ),
    );
  }
}

class DetectionBoxPainter extends CustomPainter {
  final List<DetectionBox> detections;
  final Size imageSize;
  final Size displaySize;

  DetectionBoxPainter({
    required this.detections,
    required this.imageSize,
    required this.displaySize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = displaySize.width / imageSize.width;
    final scaleY = displaySize.height / imageSize.height;

    for (final det in detections) {
      final color = _getClassColor(det.className);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final rect = Rect.fromLTRB(
        det.x1 * scaleX,
        det.y1 * scaleY,
        det.x2 * scaleX,
        det.y2 * scaleY,
      );

      canvas.drawRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        det.x1 * scaleX,
        det.y1 * scaleY - textPainter.height - 2,
        textPainter.width + 4,
        textPainter.height + 2,
      );
      canvas.drawRect(labelRect, Paint()..color = color.withOpacity(0.8));
      textPainter.paint(canvas, Offset(det.x1 * scaleX + 2, det.y1 * scaleY - textPainter.height - 1));
    }
  }

  Color _getClassColor(String className) {
    switch (className.toLowerCase()) {
      case 'person': return Colors.green;
      case 'helmet': return Colors.orange;
      case 'mask': return Colors.purple;
      case 'fire_extinguisher': return Colors.red;
      default: return Colors.blue;
    }
  }

  @override
  bool shouldRepaint(covariant DetectionBoxPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
