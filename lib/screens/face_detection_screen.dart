import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../face_detection_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/detection_results_card.dart';
import '../widgets/error_card.dart';
import '../widgets/image_display_card.dart';
import '../widgets/loading_screen.dart';

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  final FaceDetectionService _faceService = FaceDetectionService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  File? _processedImage;
  List<FaceDetectionResult> _detectedFaces = [];
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _faceService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      await _faceService.initialize();

      setState(() {
        _isInitialized = true;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _processedImage = null;
        _detectedFaces = [];
        _isProcessing = true;
        _errorMessage = null;
      });

      // Detect faces
      final faces = await _faceService.detectFaces(image.path);

      // Draw faces on image
      final outputPath = await _faceService.drawFacesOnImage(image.path, faces);

      setState(() {
        _detectedFaces = faces;
        _processedImage = File(outputPath);
        _isProcessing = false;
      });

      // Show result dialog
      if (mounted) {
        _showResultDialog(faces.length);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing image: $e';
        _isProcessing = false;
      });
    }
  }

  void _showResultDialog(int faceCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.face, color: Colors.blue),
            SizedBox(width: 8),
            Text('Detection Complete'),
          ],
        ),
        content: Text(
          faceCount == 0
              ? 'No faces detected in the image.'
              : faceCount == 1
                  ? '1 face detected!'
                  : '$faceCount faces detected!',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetImage() {
    setState(() {
      _selectedImage = null;
      _processedImage = null;
      _detectedFaces = [];
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Face Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_processedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: _resetImage,
            ),
        ],
      ),
      body: _isInitialized
          ? _buildBody()
          : LoadingScreen(
              errorMessage: _errorMessage,
              onRetry: _initializeService,
            ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image display area
            ImageDisplayCard(
              selectedImage: _selectedImage,
              processedImage: _processedImage,
              isProcessing: _isProcessing,
            ),

            const SizedBox(height: 24),

            // Action buttons
            if (_processedImage == null)
              ActionButtons(
                isProcessing: _isProcessing,
                onCameraPressed: () => _pickImage(ImageSource.camera),
                onGalleryPressed: () => _pickImage(ImageSource.gallery),
              ),

            // Detection results
            if (_detectedFaces.isNotEmpty) ...[
              const SizedBox(height: 24),
              DetectionResultsCard(detectedFaces: _detectedFaces),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              ErrorCard(errorMessage: _errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}
