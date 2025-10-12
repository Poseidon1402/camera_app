import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'face_detection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(FaceApp(cameras: cameras));
}

class FaceApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const FaceApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    // Choisit la caméra frontale si disponible, sinon la première
    final CameraDescription selectedCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    return MaterialApp(
      home: FaceDetectionScreen(camera: selectedCamera),
    );
  }
}

class FaceDetectionScreen extends StatefulWidget {
  final CameraDescription camera;
  const FaceDetectionScreen({super.key, required this.camera});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final FaceDetectionService _faceService = FaceDetectionService();
  List<Rect> _faces = [];
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    // Lance l'initialisation et attends qu'elle soit terminée avant de streamer
    _initializeControllerFuture = _controller.initialize();
    await _initializeControllerFuture;

    await _faceService.initialize();

    // Démarre le flux d'images uniquement après initialisation
    await _controller.startImageStream(_onImageAvailable);
  }

  Future<void> _onImageAvailable(CameraImage image) async {
    if (!mounted) return;
    if (_isProcessingFrame) return; // évite la ré-entrance si traitement en cours
    if (image.format.group != ImageFormatGroup.yuv420) return;

    _isProcessingFrame = true;

    // Stoppe temporairement le flux pour éviter la saturation des buffers
    try {
      if (_controller.value.isStreamingImages) {
        await _controller.stopImageStream();
      }
    } catch (_) {}

    try {
      final bytes = _convertYUV420toRGB(image);
      final boxes = await _faceService.detectFaces(bytes, image.width, image.height);
      if (!mounted) return;
      setState(() => _faces = boxes);
    } catch (e) {
      // Optionnel: logger l'erreur si besoin
      // debugPrint('Frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
      if (!mounted) return;
      // Redémarre le flux après traitement
      try {
        await _controller.startImageStream(_onImageAvailable);
      } catch (_) {}
    }
  }

  Uint8List _convertYUV420toRGB(CameraImage image) {
    // Simplified: for demo only. Consider using `image` package for accurate conversion.
    final int size = image.width * image.height * 3;
    return Uint8List(size); // placeholder empty array for demonstration
  }

  @override
  void dispose() {
    // Stoppe proprement le flux si actif, puis libère la caméra
    () async {
      try {
        if (_controller.value.isStreamingImages) {
          await _controller.stopImageStream();
        }
      } catch (_) {} finally {
        await _controller.dispose();
      }
    }();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),
                CustomPaint(
                  painter: FacePainter(_faces),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Rect> faces;
  FacePainter(this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final face in faces) {
      canvas.drawRect(face, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) => oldDelegate.faces != faces;
}
