# Face Detection App

A modern Flutter application for face detection using YuNet model with OpenCV.

## Features

- 🎯 **Face Detection**: Detect faces in images using the YuNet deep learning model
- 📸 **Camera Support**: Take photos directly from your camera
- 🖼️ **Gallery Support**: Select images from your device gallery
- 🎨 **Beautiful UI**: Modern, user-friendly Material Design 3 interface
- 📊 **Detailed Results**: View detection confidence scores and face positions
- ✨ **Visual Feedback**: See detected faces highlighted with green rectangles

## Technologies Used

- **Flutter**: Cross-platform mobile framework
- **opencv_dart**: OpenCV bindings for Dart/Flutter
- **YuNet Model**: State-of-the-art face detection model
- **image_picker**: Image selection from camera/gallery

## Installation

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)

### Steps

1. **Clone or navigate to the project directory**:
   ```bash
   cd C:\Users\Aina\StudioProjects\face_recognition
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                    # Main app entry point and UI
├── face_detection_service.dart  # Face detection logic with OpenCV
assets/
└── face_detection_yunet_2023mar.onnx  # YuNet model file
```

## How to Use

1. **Launch the app**: The app will initialize the face detection model
2. **Choose an option**:
   - Tap **"Take Photo"** to capture a new image with your camera
   - Tap **"Gallery"** to select an existing image
3. **View results**: The app will automatically detect faces and show:
   - Green rectangles around detected faces
   - Confidence scores for each detection
   - Face positions and dimensions
4. **Reset**: Tap the refresh icon to start over with a new image

## Model Information

- **Model**: YuNet (2023 March version)
- **Input**: RGB images (any size)
- **Output**: Bounding boxes with confidence scores
- **Accuracy**: High-precision face detection
- **Performance**: Optimized for mobile devices

## Configuration

You can adjust detection parameters in `face_detection_service.dart`:

```dart
_detector = cv.FaceDetectorYN.fromFile(
  modelPath,
  '',
  (320, 320),
  scoreThreshold: 0.6,    // Minimum confidence (0.0-1.0)
  nmsThreshold: 0.3,      // Non-maximum suppression
  topK: 5000,             // Maximum faces to detect
);
```

## Troubleshooting

### Common Issues

1. **"Failed to initialize"**: Make sure the model file exists in `assets/face_detection_yunet_2023mar.onnx`
2. **Camera permission denied**: Grant camera permissions in device settings
3. **Build errors**: Run `flutter clean` then `flutter pub get`

## Requirements

### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- Permissions: Camera, Storage

### iOS
- Minimum iOS: 11.0
- Permissions: Camera, Photo Library

## License

This project is for educational and demonstration purposes.

## Credits

- **YuNet Model**: OpenCV team
- **opencv_dart**: OpenCV Dart bindings
- **Flutter**: Google

---

**Developed with ❤️ using Flutter and OpenCV**
