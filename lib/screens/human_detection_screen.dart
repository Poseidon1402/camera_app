import 'package:flutter/material.dart';
import '../human_detection_service.dart';
import 'base_detection_screen.dart';

class HumanDetectionScreen extends BaseDetectionScreen<HumanDetectionResult> {
  const HumanDetectionScreen({super.key});

  @override
  State<HumanDetectionScreen> createState() => _HumanDetectionScreenState();
}

class _HumanDetectionScreenState extends BaseDetectionScreenState<HumanDetectionResult, HumanDetectionScreen> {
  final HumanDetectionService _humanService = HumanDetectionService();

  @override
  String get screenTitle => 'Human Detection';

  @override
  String get detectionTypeName => 'Person';

  @override
  IconData get screenIcon => Icons.person;

  @override
  Future<void> initializeService() async {
    await _humanService.initialize();
  }

  @override
  Future<List<HumanDetectionResult>> detectItems(String imagePath) async {
    return await _humanService.detectHumans(imagePath);
  }

  @override
  Future<String> drawItemsOnImage(String imagePath, List<HumanDetectionResult> items) async {
    return await _humanService.drawHumansOnImage(imagePath, items);
  }

  @override
  void disposeService() {
    _humanService.dispose();
  }
}
