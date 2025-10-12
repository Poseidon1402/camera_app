import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'dart:ui';

class FaceDetectionService {
  late OrtSession _session;

  Future<void> initialize() async {
    final modelData = await rootBundle.load('assets/face_detection.onnx');
    final options = OrtSessionOptions();

    // Create the ONNX session with buffer + options (required in 1.4.1)
    _session = OrtSession.fromBuffer(modelData.buffer.asUint8List(), options);
  }

  /// Run YuNet inference on the given image data
  Future<List<Rect>> detectFaces(Uint8List rgbBytes, int width, int height) async {
    // YuNet expects normalized float32 [1,3,H,W]
    final Float32List inputTensor = Float32List(width * height * 3);
    for (int i = 0; i < width * height * 3; i++) {
      inputTensor[i] = rgbBytes[i] / 255.0;
    }

    final inputShape = [1, 3, height, width];

    // Build input tensor correctly for onnxruntime 1.4.1
    final OrtValue input = OrtValueTensor.createTensorWithDataList(
      inputTensor,
      inputShape,
    );

    // Check model’s input name dynamically
    final inputName = _session.inputNames.first;

    // Prepare run options (non-null per 1.4.1 API)
    final runOptions = OrtRunOptions();

    // Run inference: signature expects OrtRunOptions, Map<String, OrtValue>, then optional output names
    final List<OrtValue?> outputs = _session.run(
      runOptions,
      {inputName: input},
      _session.outputNames,
    );

    // Handle potential null and different returned data shapes
    final OrtValue? firstOutput = outputs.isNotEmpty ? outputs.first : null;
    if (firstOutput == null) {
      return [];
    }

    final dynamic val = firstOutput.value;

    List<Rect> boxes = [];

    // Case 1: 2D list (e.g., List<List<double>> or List<List<num>>)
    if (val is List && val.isNotEmpty && val.first is List) {
      for (final dynamic row in val) {
        if (row is List && row.length >= 4) {
          final double x = (row[0] as num).toDouble();
          final double y = (row[1] as num).toDouble();
          final double w = (row[2] as num).toDouble();
          final double h = (row[3] as num).toDouble();
          boxes.add(Rect.fromLTWH(x, y, w, h));
        }
      }
      return boxes;
    }

    // Case 2: flattened Float32List (e.g., shape [N, 15])
    if (val is Float32List || val is List) {
      final List<double> flat = val is Float32List
          ? (val).toList()
          : (val as List).map((e) => (e as num).toDouble()).toList();
      const int rowSize = 15; // YuNet output per detection
      if (flat.length >= 4) {
        final int n = flat.length ~/ rowSize;
        for (int i = 0; i < n; i++) {
          final int base = i * rowSize;
          if (base + 3 < flat.length) {
            final double x = flat[base + 0];
            final double y = flat[base + 1];
            final double w = flat[base + 2];
            final double h = flat[base + 3];
            boxes.add(Rect.fromLTWH(x, y, w, h));
          }
        }
      }
      return boxes;
    }

    // Unknown output type
    return boxes;
  }
}
