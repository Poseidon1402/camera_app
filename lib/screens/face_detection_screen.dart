import 'package:flutter/material.dart';
import '../face_detection_service.dart';
import 'base_detection_screen.dart';

class FaceDetectionScreen extends BaseDetectionScreen<FaceDetectionResult> {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends BaseDetectionScreenState<FaceDetectionResult, FaceDetectionScreen> {
  final FaceDetectionService _faceService = FaceDetectionService();

  @override
  String get screenTitle => 'Face Detection';

  @override
  String get detectionTypeName => 'Face';

  @override
  IconData get screenIcon => Icons.face;

  @override
  Future<void> initializeService() async {
    await _faceService.initialize();
  }

  @override
  Future<List<FaceDetectionResult>> detectItems(String imagePath) async {
    return await _faceService.detectFaces(imagePath);
  }

  @override
  Future<String> drawItemsOnImage(String imagePath, List<FaceDetectionResult> items) async {
    return await _faceService.drawFacesOnImage(imagePath, items);
  }

  @override
  void disposeService() {
    _faceService.dispose();
  }
}
