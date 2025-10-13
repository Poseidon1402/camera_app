import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/face_detection_screen.dart';
import 'screens/human_detection_screen.dart';
import 'screens/face_recognition_screen.dart';

void main() {
  runApp(const DetectionApp());
}

class DetectionApp extends StatelessWidget {
  const DetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detection App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/face-detection': (context) => const FaceDetectionScreen(),
        '/human-detection': (context) => const HumanDetectionScreen(),
        '/face-recognition': (context) => const FaceRecognitionScreen(),
      },
    );
  }
}
