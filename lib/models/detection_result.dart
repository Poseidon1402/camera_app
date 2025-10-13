/// Base interface for detection results
abstract class DetectionResult {
  int get x;
  int get y;
  int get width;
  int get height;
  double get confidence;
}
