import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'models/detection_result.dart';

class HumanDetectionService {
  cv.Net? _net;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the MobileNetSSD model from assets
      final prototxt = await rootBundle.load('assets/MobileNetSSD_deploy.prototxt');
      final caffemodel = await rootBundle.load('assets/MobileNetSSD_deploy.caffemodel');

      // Save to temporary files
      final tempDir = await getTemporaryDirectory();
      final prototxtPath = path.join(tempDir.path, 'MobileNetSSD_deploy.prototxt');
      final caffemodelPath = path.join(tempDir.path, 'MobileNetSSD_deploy.caffemodel');

      final prototxtFile = File(prototxtPath);
      final caffemodelFile = File(caffemodelPath);

      await prototxtFile.writeAsBytes(prototxt.buffer.asUint8List());
      await caffemodelFile.writeAsBytes(caffemodel.buffer.asUint8List());

      // Create the network
      _net = cv.Net.fromCaffe(prototxtPath, caffemodelPath);

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing human detector: $e');
      rethrow;
    }
  }

  Future<List<HumanDetectionResult>> detectHumans(String imagePath) async {
    if (!_isInitialized || _net == null) {
      throw Exception('Human detector not initialized');
    }

    try {
      // Read image
      final img = cv.imread(imagePath);
      final height = img.rows;
      final width = img.cols;

      // Create blob from image
      final blob = cv.blobFromImage(
        img,
        scalefactor: 1.0 / 127.5,
        size: (300, 300),
        mean: cv.Scalar(127.5, 127.5, 127.5, 0),
        swapRB: true,
        crop: false,
      );

      // Set input and forward pass
      _net!.setInput(blob);
      final detections = _net!.forward();

      // Process detections
      final results = <HumanDetectionResult>[];
      
      // MobileNetSSD output shape: [1, 1, N, 7]
      // Reshape to 2D for easier access
      final det2D = detections.reshape(1, detections.total ~/ 7);
      final numDetections = det2D.rows;

      for (int i = 0; i < numDetections; i++) {
        // Each detection: [batchId, classId, confidence, left, top, right, bottom]
        final classId = det2D.at<double>(i, 1).toInt();
        final confidence = det2D.at<double>(i, 2);

        // Class 15 is person in MobileNetSSD
        if (classId == 15 && confidence > 0.5) {
          final left = (det2D.at<double>(i, 3) * width).toInt();
          final top = (det2D.at<double>(i, 4) * height).toInt();
          final right = (det2D.at<double>(i, 5) * width).toInt();
          final bottom = (det2D.at<double>(i, 6) * height).toInt();

          results.add(HumanDetectionResult(
            x: left,
            y: top,
            width: right - left,
            height: bottom - top,
            confidence: confidence,
          ));
        }
      }
      
      det2D.dispose();

      img.dispose();
      blob.dispose();
      detections.dispose();

      return _filterOverlappingDetections(results);
    } catch (e) {
      debugPrint('Error detecting humans: $e');
      rethrow;
    }
  }

  Future<String> drawHumansOnImage(String imagePath, List<HumanDetectionResult> humans) async {
    try {
      final img = cv.imread(imagePath);

      // Draw rectangles around detected humans
      for (final human in humans) {
        cv.rectangle(
          img,
          cv.Rect(human.x, human.y, human.width, human.height),
          cv.Scalar(0, 255, 0, 255), // Green color
          thickness: 3,
        );

        // Draw confidence score
        final text = '${(human.confidence * 100).toStringAsFixed(1)}%';
        cv.putText(
          img,
          text,
          cv.Point(human.x, human.y - 10),
          cv.FONT_HERSHEY_SIMPLEX,
          0.8,
          cv.Scalar(0, 255, 0, 255),
          thickness: 2,
        );
      }

      // Save the result
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(tempDir.path, 'detected_humans_${DateTime.now().millisecondsSinceEpoch}.jpg');
      cv.imwrite(outputPath, img);

      img.dispose();

      return outputPath;
    } catch (e) {
      debugPrint('Error drawing humans on image: $e');
      rethrow;
    }
  }

  /// Filters overlapping detections using Non-Maximum Suppression (NMS)
  List<HumanDetectionResult> _filterOverlappingDetections(
    List<HumanDetectionResult> detections, {
    double overlapThreshold = 0.3,
  }) {
    if (detections.length <= 1) return detections;

    // Sort by confidence (highest first)
    final sorted = List<HumanDetectionResult>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final filtered = <HumanDetectionResult>[];

    for (final detection in sorted) {
      bool shouldKeep = true;

      for (final kept in filtered) {
        final overlapRatio = _calculateOverlapRatio(detection, kept);
        if (overlapRatio > overlapThreshold) {
          shouldKeep = false;
          break;
        }
      }

      if (shouldKeep) {
        filtered.add(detection);
      }
    }

    return filtered;
  }

  double _calculateOverlapRatio(HumanDetectionResult d1, HumanDetectionResult d2) {
    final x1 = d1.x > d2.x ? d1.x : d2.x;
    final y1 = d1.y > d2.y ? d1.y : d2.y;
    final x2 = (d1.x + d1.width) < (d2.x + d2.width) 
        ? (d1.x + d1.width) 
        : (d2.x + d2.width);
    final y2 = (d1.y + d1.height) < (d2.y + d2.height)
        ? (d1.y + d1.height)
        : (d2.y + d2.height);

    if (x2 <= x1 || y2 <= y1) return 0.0;

    final intersectionArea = (x2 - x1) * (y2 - y1);
    final area1 = d1.width * d1.height;
    final area2 = d2.width * d2.height;
    final unionArea = area1 + area2 - intersectionArea;

    return intersectionArea / unionArea;
  }

  void dispose() {
    _net?.dispose();
    _isInitialized = false;
  }
}

class HumanDetectionResult implements DetectionResult {
  @override
  final int x;
  @override
  final int y;
  @override
  final int width;
  @override
  final int height;
  @override
  final double confidence;

  HumanDetectionResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });
}
