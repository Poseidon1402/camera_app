import 'package:flutter/material.dart';
import '../face_detection_service.dart';

class DetectionResultsCard extends StatelessWidget {
  final List<FaceDetectionResult> detectedFaces;

  const DetectionResultsCard({
    super.key,
    required this.detectedFaces,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.face, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  '${detectedFaces.length} Face${detectedFaces.length != 1 ? 's' : ''} Detected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...detectedFaces.asMap().entries.map((entry) {
              final index = entry.key;
              final face = entry.value;
              return _FaceInfoItem(
                index: index,
                face: face,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FaceInfoItem extends StatelessWidget {
  final int index;
  final FaceDetectionResult face;

  const _FaceInfoItem({
    required this.index,
    required this.face,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Position: (${face.x}, ${face.y})',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Size: ${face.width}×${face.height}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(face.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
