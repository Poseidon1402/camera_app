import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../widgets/action_buttons.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_card.dart';
import '../widgets/image_display_card.dart';
import '../widgets/loading_screen.dart';

/// Base class for detection screens to reduce boilerplate code
abstract class BaseDetectionScreen<T extends DetectionResult> extends StatefulWidget {
  const BaseDetectionScreen({super.key});
}

abstract class BaseDetectionScreenState<T extends DetectionResult, W extends BaseDetectionScreen<T>> extends State<W> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  File? _processedImage;
  List<T> _detectedItems = [];
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // Abstract methods to be implemented by subclasses
  String get screenTitle;
  String get detectionTypeName; // e.g., "Face" or "Human"
  IconData get screenIcon;
  
  Future<void> initializeService();
  Future<List<T>> detectItems(String imagePath);
  Future<String> drawItemsOnImage(String imagePath, List<T> items);
  void disposeService();

  @override
  void initState() {
    super.initState();
    _initializeServiceWrapper();
  }

  @override
  void dispose() {
    disposeService();
    super.dispose();
  }

  Future<void> _initializeServiceWrapper() async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      await initializeService();

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
        _detectedItems = [];
        _isProcessing = true;
        _errorMessage = null;
      });

      // Detect items
      final items = await detectItems(image.path);

      // Draw items on image
      final outputPath = await drawItemsOnImage(image.path, items);

      setState(() {
        _detectedItems = items;
        _processedImage = File(outputPath);
        _isProcessing = false;
      });

      // Show result dialog
      if (mounted) {
        _showResultDialog(items.length);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing image: $e';
        _isProcessing = false;
      });
    }
  }

  void _showResultDialog(int itemCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(screenIcon, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Detection Complete'),
          ],
        ),
        content: Text(
          itemCount == 0
              ? 'No ${detectionTypeName.toLowerCase()}s detected in the image.'
              : itemCount == 1
                  ? '1 $detectionTypeName detected!'
                  : '$itemCount ${detectionTypeName}s detected!',
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
      _detectedItems = [];
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          screenTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
      drawer: const AppDrawer(),
      body: _isInitialized
          ? _buildBody()
          : LoadingScreen(
              errorMessage: _errorMessage,
              onRetry: _initializeServiceWrapper,
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
            if (_detectedItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              buildResultsCard(_detectedItems),
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

  /// Build the results card - can be overridden for custom display
  Widget buildResultsCard(List<T> items) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(screenIcon, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  '${items.length} $detectionTypeName${items.length != 1 ? 's' : ''} Detected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildResultItem(index, item);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(int index, T item) {
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
                  'Position: (${item.x}, ${item.y})',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Size: ${item.width}×${item.height}',
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
              '${(item.confidence * 100).toStringAsFixed(1)}%',
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
