import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'models/detection_result.dart';

class FaceDetectionService {
  cv.FaceDetectorYN? _detector;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the YuNet model from assets
      final modelData = await rootBundle.load('assets/face_detection_yunet_2023mar.onnx');

      // Save to temporary file (opencv_dart needs a file path)
      final tempDir = await getTemporaryDirectory();
      final modelPath = path.join(tempDir.path, 'face_detection_yunet_2023mar.onnx');
      final modelFile = File(modelPath);
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());

      // Create YuNet face detector
      _detector = cv.FaceDetectorYN.fromFile(
        modelPath,
        '',
        (320, 320),
        scoreThreshold: 0.8,
        nmsThreshold: 0.3,
        topK: 5000,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing face detector: $e');
      rethrow;
    }
  }

  Future<List<FaceDetectionResult>> detectFaces(String imagePath) async {
    if (!_isInitialized || _detector == null) {
      throw Exception('Face detector not initialized');
    }

    try {
      // Read image
      final img = cv.imread(imagePath);

      // Set the input size dynamically
      _detector!.setInputSize((img.cols, img.rows));

      // Detect faces
      final faces = _detector!.detect(img);

      // Convert to result list
      final results = <FaceDetectionResult>[];

      if (faces.rows > 0) {
        for (int i = 0; i < faces.rows; i++) {
          // Each row contains: x, y, w, h, x_re, y_re, x_le, y_le, x_nt, y_nt, x_rcm, y_rcm, x_lcm, y_lcm, score
          final x = faces.at<double>(i, 0).toInt();
          final y = faces.at<double>(i, 1).toInt();
          final w = faces.at<double>(i, 2).toInt();
          final h = faces.at<double>(i, 3).toInt();
          final confidence = faces.at<double>(i, 14); // Score is at index 14

          results.add(FaceDetectionResult(
            x: x,
            y: y,
            width: w,
            height: h,
            confidence: confidence,
          ));
        }
      }

      img.dispose();
      faces.dispose();

      // Filter overlapping faces, keeping only the most confident ones
      return _filterOverlappingFaces(results);
    } catch (e) {
      debugPrint('Error detecting faces: $e');
      rethrow;
    }
  }

  /// Filters overlapping faces using Non-Maximum Suppression (NMS)
  /// Keeps only the most confident face when multiple faces overlap significantly
  List<FaceDetectionResult> _filterOverlappingFaces(List<FaceDetectionResult> faces, {double overlapThreshold = 0.3}) {
    if (faces.length <= 1) return faces;

    // Sort faces by confidence (highest first)
    final sortedFaces = List<FaceDetectionResult>.from(faces)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final filtered = <FaceDetectionResult>[];

    for (final face in sortedFaces) {
      bool shouldKeep = true;

      // Check if this face overlaps significantly with any already kept face
      for (final keptFace in filtered) {
        final overlapRatio = _calculateOverlapRatio(face, keptFace);
        if (overlapRatio > overlapThreshold) {
          shouldKeep = false;
          break;
        }
      }

      if (shouldKeep) {
        filtered.add(face);
      }
    }

    return filtered;
  }

  /// Calculates the Intersection over Union (IoU) between two face rectangles
  double _calculateOverlapRatio(FaceDetectionResult face1, FaceDetectionResult face2) {
    // Calculate intersection rectangle
    final x1 = face1.x > face2.x ? face1.x : face2.x;
    final y1 = face1.y > face2.y ? face1.y : face2.y;
    final x2 = (face1.x + face1.width) < (face2.x + face2.width) 
        ? (face1.x + face1.width) 
        : (face2.x + face2.width);
    final y2 = (face1.y + face1.height) < (face2.y + face2.height)
        ? (face1.y + face1.height)
        : (face2.y + face2.height);

    // If no intersection
    if (x2 <= x1 || y2 <= y1) return 0.0;

    final intersectionArea = (x2 - x1) * (y2 - y1);
    final face1Area = face1.width * face1.height;
    final face2Area = face2.width * face2.height;
    final unionArea = face1Area + face2Area - intersectionArea;

    return intersectionArea / unionArea;
  }

  Future<String> drawFacesOnImage(String imagePath, List<FaceDetectionResult> faces) async {
    try {
      final img = cv.imread(imagePath);

      // Draw rectangles around detected faces
      for (final face in faces) {
        cv.rectangle(
          img,
          cv.Rect(face.x, face.y, face.width, face.height),
          cv.Scalar(0, 255, 0, 255), // Green color
          thickness: 3,
        );

        // Draw confidence score
        final text = '${(face.confidence * 100).toStringAsFixed(1)}%';
        cv.putText(
          img,
          text,
          cv.Point(face.x, face.y - 10),
          cv.FONT_HERSHEY_SIMPLEX,
          0.8,
          cv.Scalar(0, 255, 0, 255),
          thickness: 2,
        );
      }

      // Save the result
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(tempDir.path, 'detected_faces_${DateTime.now().millisecondsSinceEpoch}.jpg');
      cv.imwrite(outputPath, img);

      img.dispose();

      return outputPath;
    } catch (e) {
      debugPrint('Error drawing faces on image: $e');
      rethrow;
    }
  }

  void dispose() {
    _detector?.dispose();
    _isInitialized = false;
  }
}

class FaceDetectionResult implements DetectionResult {
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

  FaceDetectionResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });
}
