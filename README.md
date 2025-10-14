# Face Recognition App

A comprehensive Flutter application featuring face detection, human detection, and face recognition powered by deep learning models (YuNet, MobileNetSSD, EdgeFace) with OpenCV and ONNX Runtime.

## Features

### Face Detection
- State-of-the-art YuNet model with facial landmarks detection
- 5-point landmarks: eyes, nose, and mouth corners
- Fast and accurate face localization
- Confidence scoring for each detection
- Non-Maximum Suppression (NMS) for overlapping faces

### Human Detection  
- Efficient MobileNetSSD model for person detection
- Identifies and localizes people in images
- Multi-person support in single images
- Lightweight model optimized for mobile devices
- Real-time processing capability

### Face Recognition
- Advanced EdgeFace model with ONNX Runtime
- Automatic face alignment using detected landmarks
- Face enrollment with custom names
- Face identification with similarity scores
- Persistent local storage using SharedPreferences
- Configurable similarity threshold (default: 50%)
- 512-dimensional embedding vectors

### User Experience
- Camera and gallery image selection
- Material Design 3 with gradient cards
- Organized navigation drawer
- Visual feedback with color-coded bounding boxes
- Easy image reset functionality

## Architecture

### Design Patterns
- **Service Layer Pattern**: Separation of business logic from UI
- **Base Class Pattern**: Generic `BaseDetectionScreen` eliminates code duplication
- **Factory Pattern**: Reusable widget components

### Project Structure
```
lib/
├── main.dart                           # App entry point with routing
├── screens/
│   ├── home_screen.dart               # Dashboard with feature cards
│   ├── base_detection_screen.dart     # Generic base class for detection features
│   ├── face_detection_screen.dart     # Face detection implementation
│   ├── human_detection_screen.dart    # Human detection implementation
│   └── face_recognition_screen.dart   # Face recognition with enrollment/recognition tabs
├── services/
│   ├── face_detection_service.dart    # YuNet face detection with OpenCV
│   ├── human_detection_service.dart   # MobileNetSSD human detection
│   └── face_recognition_service.dart  # EdgeFace recognition with ONNX Runtime
├── widgets/
│   ├── app_drawer.dart                # Navigation drawer
│   ├── action_buttons.dart            # Reusable camera/gallery buttons
│   ├── error_card.dart                # Error display component
│   ├── image_display_card.dart        # Image container component
│   └── loading_screen.dart            # Loading indicator
├── models/
│   └── detection_result.dart          # Detection result interfaces
└── assets/
    ├── face_detection_yunet_2023mar.onnx  # YuNet model
    ├── MobileNetSSD_deploy.prototxt       # MobileNetSSD config
    ├── MobileNetSSD_deploy.caffemodel     # MobileNetSSD weights
    └── edgeface.onnx                      # EdgeFace recognition model
```

## Technologies Used

### Core Frameworks
- **Flutter** (^3.9.2): Cross-platform mobile framework
- **Dart**: Programming language

### Computer Vision & ML
- **opencv_dart** (^1.2.4): OpenCV bindings for Dart/Flutter
- **onnxruntime** (^1.4.1): ONNX Runtime for EdgeFace model inference
- **image** (^4.5.4): Image processing and manipulation

### Models
- **YuNet**: Face detection with facial landmarks (OpenCV)
- **MobileNetSSD**: Human detection (Caffe model)
- **EdgeFace**: Face recognition with embeddings (ONNX)

### Utilities
- **image_picker** (^1.0.7): Camera and gallery integration
- **path_provider** (^2.1.2): File system access
- **shared_preferences** (^2.2.2): Local data persistence

## Prerequisites

- **Flutter SDK**: 3.9.2 or higher
- **Dart SDK**: Included with Flutter
- **Android Studio** or **Xcode**: For mobile development
- **Android**: API Level 21+ (Android 5.0+)
- **iOS**: iOS 11.0+

## Installation

### 1. Clone or Navigate to Project
```bash
cd face_recognition
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Verify Model Files
Ensure all model files are in the `assets/` directory:
- `face_detection_yunet_2023mar.onnx` (YuNet)
- `MobileNetSSD_deploy.caffemodel` (MobileNetSSD weights)
- `MobileNetSSD_deploy.prototxt` (MobileNetSSD config)
- `edgeface.onnx` (EdgeFace recognition)

### 4. Run the App
```bash
# For Android
flutter run

# For iOS
flutter run --release

# For specific device
flutter run -d <device_id>
```

### 5. Build Release APK (Android)
```bash
flutter build apk --release
```

## 📖 Usage Guide

### Home Screen
The app opens to a dashboard with three feature cards:
1. **Face Detection**: Detect faces with landmarks
2. **Human Detection**: Identify people in images  
3. **Face Recognition**: Enroll and recognize faces

### Face Detection
1. Tap "Face Detection" from home or drawer
2. Choose "Take Photo" or "Gallery"
3. View detected faces with green bounding boxes
4. See confidence scores and face positions

### Human Detection
1. Tap "Human Detection" from home or drawer
2. Select image source (camera/gallery)
3. View detected people with blue bounding boxes
4. Check detection confidence for each person

### Face Recognition

#### Enrolling Faces
1. Navigate to "Face Recognition" feature
2. Switch to "Enroll Face" tab
3. Enter a name for the person
4. Take photo or select from gallery
5. System automatically:
   - Detects face with landmarks
   - Aligns face to standard pose
   - Extracts embedding using EdgeFace
   - Saves to local database

#### Recognizing Faces
1. Switch to "Recognize" tab
2. Take photo or select image
3. System will:
   - Detect and align face
   - Extract embedding
   - Compare with enrolled faces
   - Show match with similarity percentage
4. View recognized person's name and confidence

#### Managing Enrolled Faces
- View all registered faces in the list
- Delete faces by tapping the delete icon
- Database persists between app sessions

## 🧠 Model Information

### YuNet Face Detection
- **Version**: 2023 March
- **Input**: RGB images (any resolution)
- **Output**: Bounding boxes + 5 facial landmarks (eyes, nose, mouth corners)
- **Framework**: OpenCV DNN module
- **Accuracy**: High-precision face detection
- **Speed**: Optimized for real-time mobile inference

### MobileNetSSD Human Detection
- **Architecture**: MobileNet v1 + SSD
- **Input**: 300x300 RGB images
- **Output**: Bounding boxes with class labels
- **Framework**: OpenCV DNN with Caffe model
- **Classes**: 21 COCO classes (person detection used)
- **Performance**: Lightweight and fast

### EdgeFace Recognition
- **Architecture**: Transformer-based face recognition
- **Input**: 112x112 aligned RGB face images
- **Output**: 512-dimensional embedding vectors
- **Framework**: ONNX Runtime
- **Accuracy**: State-of-the-art face recognition
- **Preprocessing**: 
  - Face alignment using similarity transformation
  - Normalization: `(pixel - 127.5) / 127.5`
- **Matching**: Cosine similarity between embeddings

## ⚙️ Configuration

### Face Detection Parameters
Edit `lib/services/face_detection_service.dart`:
```dart
_detector = cv.FaceDetectorYN.fromFile(
  modelPath,
  '',
  (320, 320),
  scoreThreshold: 0.8,    // Confidence threshold (0.0-1.0)
  nmsThreshold: 0.3,      // Non-maximum suppression
  topK: 5000,             // Max faces to detect
);
```

### Human Detection Parameters
Edit `lib/services/human_detection_service.dart`:
```dart
const double confidenceThreshold = 0.5;  // Detection confidence
const int inputWidth = 300;              // Model input width
const int inputHeight = 300;             // Model input height
```

### Face Recognition Parameters
Edit `lib/services/face_recognition_service.dart`:
```dart
const double recognitionThreshold = 0.5;  // Similarity threshold (0.0-1.0)
// Higher threshold = stricter matching
// Lower threshold = more lenient matching
```

### Face Alignment
The system uses 5-point landmarks for face alignment:
```dart
// Target positions for 112x112 face
final dstPoints = [
  cv.Point2f(38.2946, 51.6963),  // right eye
  cv.Point2f(73.5318, 51.5014),  // left eye
  cv.Point2f(56.0252, 71.7366),  // nose tip
  cv.Point2f(41.5493, 92.3655),  // right mouth corner
  cv.Point2f(70.7299, 92.2041),  // left mouth corner
];
```

## 🔍 Technical Implementation

### Face Alignment Process
1. **Landmark Detection**: YuNet detects 5 facial landmarks
2. **Similarity Transform**: Calculates affine transformation matrix
3. **Warping**: Aligns face to standard 112x112 pose
4. **Normalization**: Preprocesses for EdgeFace model
5. **Embedding Extraction**: Generates 512-D feature vector

### Face Recognition Pipeline
```
Image → YuNet Detection → Landmark Extraction → Face Alignment 
→ Normalization → EdgeFace ONNX Runtime → Embedding Vector 
→ Cosine Similarity → Recognition Result
```

### Code Quality
- **0 Flutter Analyze Errors**: Clean, production-ready code
- **Type Safety**: Strong typing throughout
- **Error Handling**: Comprehensive try-catch blocks
- **Memory Management**: Proper resource disposal
- **Null Safety**: Full null-safety support

## 🐛 Troubleshooting

### Initialization Errors
**Problem**: "Failed to initialize face detector/recognizer"
- **Solution**: Verify all model files exist in `assets/` folder
- Check `pubspec.yaml` includes all assets
- Run `flutter clean && flutter pub get`

### Build Errors
**Problem**: Gradle build failed
- **Solution**: Check `android/app/build.gradle.kts` syntax
- Ensure NDK version compatibility
- Verify `abiFilters` configuration:
  ```kotlin
  ndk {
      abiFilters += listOf("arm64-v8a", "armeabi-v7a")
  }
  ```

### Permission Issues
**Problem**: Camera or gallery access denied
- **Android**: Grant permissions in Settings → Apps → Permissions
- **iOS**: Grant permissions when prompted
- Check `AndroidManifest.xml` and `Info.plist` have required permissions

### Recognition Issues
**Problem**: Face recognition not accurate
- **Solution**: 
  - Enroll faces with good lighting
  - Use frontal face images
  - Avoid extreme angles or occlusions
  - Adjust `recognitionThreshold` if needed
  - Re-enroll faces if needed

### Memory Issues
**Problem**: App crashes or runs out of memory
- **Solution**:
  - Use release build: `flutter run --release`
  - Reduce image resolution before processing
  - Ensure proper disposal of OpenCV Mat objects

### Performance Issues
**Problem**: Slow detection/recognition
- **Solution**:
  - Use release mode (much faster than debug)
  - Reduce image resolution
  - Check device specifications
  - Close background apps

## 📱 Platform Requirements

### Android
- **Minimum SDK**: 21 (Android 5.0 Lollipop)
- **Target SDK**: 34 (Android 14)
- **Permissions Required**:
  - `CAMERA`: For taking photos
  - `READ_EXTERNAL_STORAGE`: For gallery access
  - `WRITE_EXTERNAL_STORAGE`: For saving images (API < 29)
- **Native Libraries**: arm64-v8a, armeabi-v7a

### iOS
- **Minimum Version**: iOS 11.0
- **Permissions Required**:
  - Camera (`NSCameraUsageDescription`)
  - Photo Library (`NSPhotoLibraryUsageDescription`)
- **Architectures**: arm64

## 🚦 Performance Benchmarks

### Processing Times (Release Mode, Mid-Range Device)
- **Face Detection**: ~50-150ms per image
- **Human Detection**: ~100-200ms per image  
- **Face Recognition**: ~200-400ms per enrollment/recognition
- **Face Alignment**: ~20-50ms per face

### Memory Usage
- **Face Detection**: ~50-100 MB
- **Human Detection**: ~80-150 MB
- **Face Recognition**: ~150-250 MB (includes ONNX Runtime)

## 🔒 Privacy & Security

- **Local Processing**: All detection and recognition happens on-device
- **No Cloud**: No data sent to external servers
- **Secure Storage**: Face embeddings stored locally with SharedPreferences
- **User Control**: Users can delete enrolled faces anytime
- **No Biometric Data**: Stores mathematical embeddings, not raw images

## 🎓 Learning Resources

### Understanding the Code
- **Base Detection Pattern**: See `base_detection_screen.dart` for reusable screen logic
- **Service Layer**: Each detection/recognition feature has its own service class
- **OpenCV Integration**: Study `face_detection_service.dart` for OpenCV usage
- **ONNX Runtime**: See `face_recognition_service.dart` for ONNX integration

### Key Concepts
1. **Face Alignment**: Why it's crucial for recognition accuracy
2. **Embedding Vectors**: How faces are represented mathematically
3. **Cosine Similarity**: How face matching works
4. **Non-Maximum Suppression**: Filtering overlapping detections

## 📄 License

This project is for educational and demonstration purposes.

**Note**: Model licenses may vary:
- YuNet: OpenCV license (Apache 2.0)
- MobileNetSSD: Apache 2.0
- EdgeFace: Check model provider's license

## 🙏 Credits

- **OpenCV Team**: YuNet face detection model
- **opencv_dart Contributors**: OpenCV bindings for Dart
- **Microsoft**: ONNX Runtime
- **EdgeFace Authors**: Face recognition model
- **Google**: Flutter framework and MobileNetSSD
- **Flutter Community**: Various packages used

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Add more detection models
- Implement liveness detection
- Add face verification mode
- Support video processing
- Improve UI/UX
- Add unit tests
- Optimize performance

## 📞 Support

For issues and questions:
- Check the troubleshooting section above
- Review Flutter and OpenCV documentation
- Check package documentation for opencv_dart and onnxruntime

---

**Built with ❤️ using Flutter, OpenCV, and ONNX Runtime**

*A comprehensive computer vision application showcasing face detection, human detection, and face recognition with state-of-the-art deep learning models.*
