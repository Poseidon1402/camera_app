import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'face_detection_service.dart';

class FaceRecognitionService {
  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  bool _isInitialized = false;
  
  final FaceDetectionService _detectionService = FaceDetectionService();
  final Map<String, List<double>> _faceDatabase = {};

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize ONNX Runtime
      OrtEnv.instance.init();
      
      // Initialize face detector
      await _detectionService.initialize();

      // Load the EdgeFace model from assets
      final modelData = await rootBundle.load('assets/edgeface.onnx');
      final bytes = modelData.buffer.asUint8List();

      // Save to temporary file (ONNX Runtime needs a file path)
      final tempDir = await getTemporaryDirectory();
      final modelPath = path.join(tempDir.path, 'edgeface.onnx');
      final modelFile = File(modelPath);
      await modelFile.writeAsBytes(bytes);

      // Create session options
      _sessionOptions = OrtSessionOptions();

      // Create ONNX Runtime session
      _session = OrtSession.fromFile(File(modelPath), _sessionOptions!);

      // Load saved face database
      await _loadFaceDatabase();

      _isInitialized = true;
      debugPrint('Face recognition service initialized successfully with ONNX Runtime');
      debugPrint('Model inputs: ${_session!.inputNames}');
      debugPrint('Model outputs: ${_session!.outputNames}');
    } catch (e) {
      debugPrint('Error initializing face recognizer: $e');
      rethrow;
    }
  }

  Future<List<double>?> extractFaceEmbedding(String imagePath) async {
    if (!_isInitialized || _session == null) {
      throw Exception('Face recognizer not initialized');
    }

    try {
      // Read image first
      final cvImage = cv.imread(imagePath);
      
      // Detect face with landmarks
      final faces = await _detectionService.detectFaces(imagePath);
      
      if (faces.isEmpty) {
        debugPrint('No face detected in image');
        cvImage.dispose();
        return null;
      }

      // Use the first detected face (highest confidence)
      final face = faces.first;
      
      // Get face landmarks (eyes, nose, mouth corners)
      final landmarks = face.landmarks;
      
      if (landmarks.isEmpty) {
        debugPrint('No landmarks detected, using crop without alignment');
        // Fall back to simple crop
        final alignedFace = _cropFaceWithoutAlignment(cvImage, face);
        cvImage.dispose();
        
        final inputTensor = _preprocessImage(alignedFace);
        final embedding = await _runInference(inputTensor);
        
        return embedding;
      }

      // Align face using landmarks (eyes, nose, mouth)
      final alignedFace = _alignFace(cvImage, landmarks);
      cvImage.dispose();
      
      if (alignedFace == null) {
        debugPrint('Failed to align face');
        return null;
      }

      // Normalize and convert to tensor format
      final inputTensor = _preprocessImage(alignedFace);

      // Run inference
      final embedding = await _runInference(inputTensor);

      debugPrint('Extracted embedding with ${embedding.length} features');
      return embedding;
    } catch (e) {
      debugPrint('Error extracting face embedding: $e');
      rethrow;
    }
  }

  /// Run inference on preprocessed image
  Future<List<double>> _runInference(OrtValueTensor inputTensor) async {
    final inputs = {'input': inputTensor};
    final runOptions = OrtRunOptions();
    final outputs = _session!.run(runOptions, inputs);

    // Extract embedding from output
    final embedding = _extractEmbedding(outputs);

    runOptions.release();
    for (final value in outputs) {
      value?.release();
    }
    inputTensor.release();

    return embedding;
  }

  /// Crop face without alignment (fallback method)
  img.Image _cropFaceWithoutAlignment(cv.Mat cvImage, dynamic face) {
    // Convert cv.Mat to img.Image
    final (_, bytes) = cv.imencode('.jpg', cvImage);
    final image = img.decodeImage(bytes)!;

    // Crop face region with padding
    final padding = 10;
    final x = max(0, face.x - padding);
    final y = max(0, face.y - padding);
    final width = min(image.width - x, face.width + 2 * padding);
    final height = min(image.height - y, face.height + 2 * padding);

    final faceCrop = img.copyCrop(image, x: x, y: y, width: width, height: height);

    // Resize to model input size (112x112 for face recognition)
    return img.copyResize(faceCrop, width: 112, height: 112);
  }

  /// Align face using detected landmarks
  img.Image? _alignFace(cv.Mat cvImage, List<cv.Point2f> landmarks) {
    try {
      // Standard face template for 112x112 aligned face
      // These are the ideal positions for a frontal face
      // YuNet provides: right eye, left eye, nose, right mouth corner, left mouth corner
      if (landmarks.length < 5) {
        debugPrint('Insufficient landmarks for alignment: ${landmarks.length}');
        return null;
      }

      // Target landmark positions for 112x112 face (standard alignment)
      // Order: right_eye, left_eye, nose_tip, right_mouth_corner, left_mouth_corner
      final dstPoints = [
        cv.Point2f(38.2946, 51.6963),  // right eye
        cv.Point2f(73.5318, 51.5014),  // left eye
        cv.Point2f(56.0252, 71.7366),  // nose tip
        cv.Point2f(41.5493, 92.3655),  // right mouth corner
        cv.Point2f(70.7299, 92.2041),  // left mouth corner
      ];

      // Create VecPoint2f from landmarks
      final srcVec = cv.VecPoint2f.fromList(landmarks);
      final dstVec = cv.VecPoint2f.fromList(dstPoints);

      // Estimate similarity transform (rotation, scale, translation)
      final (transformMatrix, _) = cv.estimateAffinePartial2D(srcVec, dstVec);
      
      if (transformMatrix.isEmpty) {
        debugPrint('Failed to estimate transform matrix');
        srcVec.dispose();
        dstVec.dispose();
        return null;
      }

      // Apply transformation to align face
      final alignedMat = cv.warpAffine(
        cvImage,
        transformMatrix,
        (112, 112),
        flags: cv.INTER_LINEAR,
        borderMode: cv.BORDER_CONSTANT,
        borderValue: cv.Scalar(0, 0, 0, 0),
      );

      // Convert to img.Image
      final (_, bytes) = cv.imencode('.jpg', alignedMat);
      final alignedImage = img.decodeImage(bytes);

      // Cleanup
      srcVec.dispose();
      dstVec.dispose();
      transformMatrix.dispose();
      alignedMat.dispose();

      return alignedImage;
    } catch (e) {
      debugPrint('Error aligning face: $e');
      return null;
    }
  }

  OrtValueTensor _preprocessImage(img.Image image) {
    // EdgeFace expects input shape: [1, 3, 112, 112]
    final inputSize = 112;
    final inputData = Float32List(1 * 3 * inputSize * inputSize);

    int idx = 0;
    // Convert to CHW format (Channel, Height, Width) and normalize
    for (int c = 0; c < 3; c++) {
      for (int h = 0; h < inputSize; h++) {
        for (int w = 0; w < inputSize; w++) {
          final pixel = image.getPixel(w, h);
          double value;
          
          if (c == 0) {
            value = pixel.r / 255.0; // Red channel
          } else if (c == 1) {
            value = pixel.g / 255.0; // Green channel
          } else {
            value = pixel.b / 255.0; // Blue channel
          }
          
          // Normalize to [-1, 1] range (common for face recognition models)
          value = (value - 0.5) * 2.0;
          
          inputData[idx++] = value;
        }
      }
    }

    return OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, 3, inputSize, inputSize],
    );
  }

  List<double> _extractEmbedding(List<OrtValue?> outputs) {
    if (outputs.isEmpty) {
      throw Exception('No outputs from model');
    }

    // Get the first output (embedding)
    final outputValue = outputs.first;
    if (outputValue == null) {
      throw Exception('Output value is null');
    }

    final outputTensor = outputValue as OrtValueTensor;
    final outputData = outputTensor.value;
    
    // Flatten the output to a 1D list
    final embedding = <double>[];
    
    void flattenList(dynamic data) {
      if (data is List) {
        for (final item in data) {
          flattenList(item);
        }
      } else if (data is num) {
        embedding.add(data.toDouble());
      }
    }
    
    flattenList(outputData);

    if (embedding.isEmpty) {
      throw Exception('Failed to extract embedding from output');
    }

    return embedding;
  }

  Future<bool> registerFace(String name, String imagePath) async {
    if (!_isInitialized) {
      throw Exception('Face recognizer not initialized');
    }

    try {
      final embedding = await extractFaceEmbedding(imagePath);
      
      if (embedding == null) {
        debugPrint('Failed to extract embedding for registration');
        return false;
      }

      _faceDatabase[name] = embedding;
      await _saveFaceDatabase();
      
      debugPrint('Face registered for: $name');
      return true;
    } catch (e) {
      debugPrint('Error registering face: $e');
      rethrow;
    }
  }

  Future<FaceRecognitionResult?> recognizeFace(String imagePath) async {
    if (!_isInitialized) {
      throw Exception('Face recognizer not initialized');
    }

    if (_faceDatabase.isEmpty) {
      debugPrint('Face database is empty');
      return null;
    }

    try {
      final embedding = await extractFaceEmbedding(imagePath);
      
      if (embedding == null) {
        debugPrint('No face detected for recognition');
        return null;
      }

      // Find the best match
      String? bestMatch;
      double bestSimilarity = -1.0;

      for (final entry in _faceDatabase.entries) {
        final similarity = _cosineSimilarity(embedding, entry.value);
        debugPrint('Comparing with ${entry.key}: similarity = $similarity');
        
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = entry.key;
        }
      }

      // Threshold for recognition (adjust based on your model)
      const double recognitionThreshold = 0.4;
      
      if (bestSimilarity >= recognitionThreshold) {
        debugPrint('Face recognized: $bestMatch with similarity: $bestSimilarity');
        return FaceRecognitionResult(
          name: bestMatch!,
          similarity: bestSimilarity,
        );
      }

      debugPrint('No match found above threshold. Best similarity: $bestSimilarity');
      return null;
    } catch (e) {
      debugPrint('Error recognizing face: $e');
      rethrow;
    }
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Embeddings must have the same length');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  List<String> getRegisteredFaces() {
    return _faceDatabase.keys.toList();
  }

  Future<bool> deleteFace(String name) async {
    if (_faceDatabase.containsKey(name)) {
      _faceDatabase.remove(name);
      await _saveFaceDatabase();
      debugPrint('Face deleted: $name');
      return true;
    }
    return false;
  }

  Future<void> _saveFaceDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(_faceDatabase);
      await prefs.setString('face_database', jsonData);
      debugPrint('Face database saved with ${_faceDatabase.length} faces');
    } catch (e) {
      debugPrint('Error saving face database: $e');
    }
  }

  Future<void> _loadFaceDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString('face_database');
      
      if (jsonData != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonData);
        _faceDatabase.clear();
        
        decoded.forEach((key, value) {
          _faceDatabase[key] = List<double>.from(value);
        });
        
        debugPrint('Face database loaded with ${_faceDatabase.length} faces');
      }
    } catch (e) {
      debugPrint('Error loading face database: $e');
    }
  }

  Future<String> drawRecognizedFaceOnImage(String imagePath, FaceRecognitionResult result) async {
    try {
      final cvImage = cv.imread(imagePath);
      final faces = await _detectionService.detectFaces(imagePath);

      if (faces.isNotEmpty) {
        final face = faces.first;
        
        // Draw rectangle
        cv.rectangle(
          cvImage,
          cv.Rect(face.x, face.y, face.width, face.height),
          cv.Scalar(0, 255, 0, 255),
          thickness: 3,
        );

        // Draw name
        cv.putText(
          cvImage,
          result.name,
          cv.Point(face.x, face.y - 30),
          cv.FONT_HERSHEY_SIMPLEX,
          1.0,
          cv.Scalar(0, 255, 0, 255),
          thickness: 2,
        );

        // Draw similarity score
        final text = '${(result.similarity * 100).toStringAsFixed(1)}%';
        cv.putText(
          cvImage,
          text,
          cv.Point(face.x, face.y - 5),
          cv.FONT_HERSHEY_SIMPLEX,
          0.7,
          cv.Scalar(0, 255, 0, 255),
          thickness: 2,
        );
      }

      // Save the result
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(tempDir.path, 'recognized_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
      cv.imwrite(outputPath, cvImage);

      cvImage.dispose();

      return outputPath;
    } catch (e) {
      debugPrint('Error drawing recognized face on image: $e');
      rethrow;
    }
  }

  void dispose() {
    _session?.release();
    _sessionOptions?.release();
    _detectionService.dispose();
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}

class FaceRecognitionResult {
  final String name;
  final double similarity;

  FaceRecognitionResult({
    required this.name,
    required this.similarity,
  });
}