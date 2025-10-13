import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../face_recognition_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/loading_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> with SingleTickerProviderStateMixin {
  final FaceRecognitionService _recognitionService = FaceRecognitionService();
  final ImagePicker _picker = ImagePicker();
  
  late TabController _tabController;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recognitionService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      await _recognitionService.initialize();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Face Recognition',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: _isInitialized
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.person_add), text: 'Enroll'),
                  Tab(icon: Icon(Icons.face_retouching_natural), text: 'Recognize'),
                ],
              )
            : null,
      ),
      drawer: const AppDrawer(),
      body: _isInitialized
          ? TabBarView(
              controller: _tabController,
              children: [
                _EnrollmentTab(
                  recognitionService: _recognitionService,
                  picker: _picker,
                ),
                _RecognitionTab(
                  recognitionService: _recognitionService,
                  picker: _picker,
                ),
              ],
            )
          : LoadingScreen(
              errorMessage: _errorMessage,
              onRetry: _initializeService,
            ),
    );
  }
}

// Enrollment Tab
class _EnrollmentTab extends StatefulWidget {
  final FaceRecognitionService recognitionService;
  final ImagePicker picker;

  const _EnrollmentTab({
    required this.recognitionService,
    required this.picker,
  });

  @override
  State<_EnrollmentTab> createState() => _EnrollmentTabState();
}

class _EnrollmentTabState extends State<_EnrollmentTab> {
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;
  bool _isProcessing = false;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await widget.picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _message = null;
      });
    } catch (e) {
      setState(() {
        _message = 'Error picking image: $e';
      });
    }
  }

  Future<void> _enrollFace() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _message = 'Please enter a name';
      });
      return;
    }

    if (_selectedImage == null) {
      setState(() {
        _message = 'Please select an image';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _message = null;
    });

    try {
      final success = await widget.recognitionService.registerFace(
        _nameController.text.trim(),
        _selectedImage!.path,
      );

      if (success) {
        setState(() {
          _message = 'Face enrolled successfully!';
          _selectedImage = null;
          _nameController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Face enrolled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _message = 'No face detected in the image';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error enrolling face: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enroll a New Face',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take or select a photo and enter a name to register a new face.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Name input
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter person\'s name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            enabled: !_isProcessing,
          ),
          const SizedBox(height: 24),

          // Image display
          Card(
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No image selected',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Image picker buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Camera'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Gallery'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Enroll button
          ElevatedButton(
            onPressed: _isProcessing ? null : _enrollFace,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Enroll Face',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),

          // Message display
          if (_message != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _message!.contains('success') ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('success') ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ),
            ),
          ],

          // Registered faces list
          const SizedBox(height: 24),
          _RegisteredFacesList(recognitionService: widget.recognitionService),
        ],
      ),
    );
  }
}

// Recognition Tab
class _RecognitionTab extends StatefulWidget {
  final FaceRecognitionService recognitionService;
  final ImagePicker picker;

  const _RecognitionTab({
    required this.recognitionService,
    required this.picker,
  });

  @override
  State<_RecognitionTab> createState() => _RecognitionTabState();
}

class _RecognitionTabState extends State<_RecognitionTab> {
  File? _selectedImage;
  File? _processedImage;
  bool _isProcessing = false;
  String? _message;
  FaceRecognitionResult? _recognitionResult;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await widget.picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _processedImage = null;
        _recognitionResult = null;
        _message = null;
        _isProcessing = true;
      });

      // Recognize face
      final result = await widget.recognitionService.recognizeFace(image.path);

      if (result != null) {
        final outputPath = await widget.recognitionService.drawRecognizedFaceOnImage(
          image.path,
          result,
        );

        setState(() {
          _recognitionResult = result;
          _processedImage = File(outputPath);
          _message = 'Recognized: ${result.name}';
        });
      } else {
        setState(() {
          _message = 'Face not recognized or not in database';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _processedImage = null;
      _recognitionResult = null;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recognize a Face',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take or select a photo to identify a registered face.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Image display
          Card(
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isProcessing
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing...'),
                        ],
                      ),
                    )
                  : _processedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _processedImage!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.face_retouching_natural,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No image selected',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          if (_processedImage == null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('Camera'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('Gallery'),
                    ),
                  ),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('Try Another'),
              ),
            ),

          // Result display
          if (_recognitionResult != null) ...[
            const SizedBox(height: 24),
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _recognitionResult!.name,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              Text(
                                'Similarity: ${(_recognitionResult!.similarity * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Message display
          if (_message != null && _recognitionResult == null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Registered Faces List Widget
class _RegisteredFacesList extends StatefulWidget {
  final FaceRecognitionService recognitionService;

  const _RegisteredFacesList({
    required this.recognitionService,
  });

  @override
  State<_RegisteredFacesList> createState() => _RegisteredFacesListState();
}

class _RegisteredFacesListState extends State<_RegisteredFacesList> {
  @override
  Widget build(BuildContext context) {
    final registeredFaces = widget.recognitionService.getRegisteredFaces();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registered Faces (${registeredFaces.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (registeredFaces.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No faces enrolled yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ...registeredFaces.map((name) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteFace(name),
                  ),
                ),
              )),
      ],
    );
  }

  Future<void> _deleteFace(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Face'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.recognitionService.deleteFace(name);
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name deleted successfully')),
        );
      }
    }
  }
}
