import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math'; // Thêm dòng này để tính mũ (exp)

class LocalAIService {
  // --- PHẦN 1: SINGLETON (QUAN TRỌNG NHẤT) ---
  // Giúp biến _interpreter sống mãi, không bị mất đi
  static final LocalAIService _instance = LocalAIService._internal();

  factory LocalAIService() {
    return _instance;
  }

  LocalAIService._internal();
  // --------------------------------------------

  Interpreter? _interpreter;
  List<String>? _labels;

  static const String modelPath = "assets/models/mobilenet_v3.tflite";
  static const String labelPath = "assets/models/labels.txt";

  /// Hàm load model (Chỉ chạy 1 lần)
  Future<void> loadModel() async {
    // Nếu đã load rồi thì không làm gì cả, tránh tốn RAM
    if (_interpreter != null) {
      print("♻️ Model đã có sẵn, không cần load lại.");
      return;
    }

    try {
      print("🔄 Đang load Model từ assets...");
      _interpreter = await Interpreter.fromAsset(modelPath);
      print("✅ Load Model thành công!");

      // Load nhãn
      final labelData = await rootBundle.loadString(labelPath);
      _labels = labelData.split('\n');
      // Fix lỗi nhãn trống ở cuối file (nếu có)
      _labels!.removeWhere((item) => item.trim().isEmpty);

      print("✅ Load Labels thành công: ${_labels!.length} nhãn");
    } catch (e) {
      print("❌ Lỗi load model: $e");
    }
  }

  Future<String> predictImage(String imagePath) async {
    print("📍 [1] Bắt đầu suy luận...");

    if (_interpreter == null) {
      await loadModel();
      if (_interpreter == null) return "Lỗi: Không thể load Model!";
    }

    try {
      // 1. Đọc và xử lý ảnh
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) return "Lỗi: File ảnh không tồn tại";

      var imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return "Lỗi: Không đọc được ảnh";

      img.Image resizedImage = img.copyResize(
        originalImage,
        width: 224,
        height: 224,
      );

      // 2. Chuyển đổi sang mảng Float32
      var inputBytes = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          var pixel = resizedImage.getPixel(x, y);
          inputBytes[pixelIndex++] = pixel.r / 255.0;
          inputBytes[pixelIndex++] = pixel.g / 255.0;
          inputBytes[pixelIndex++] = pixel.b / 255.0;
        }
      }

      var inputTensor = inputBytes.reshape([1, 224, 224, 3]);
      var outputTensor = List.filled(1 * 1001, 0.0).reshape([1, 1001]);

      // 3. Chạy Model
      _interpreter!.run(inputTensor, outputTensor);

      // 4. Xử lý kết quả (FIX LOGITS -> PROBABILITY)
      // Lấy danh sách điểm thô ra
      List<double> rawLogits = List<double>.from(outputTensor[0]);

      // ==> GỌI HÀM SOFTMAX Ở ĐÂY <==
      List<double> probabilities = _softmax(rawLogits);

      // Tìm cái nào cao nhất
      double maxScore = -1;
      int maxIndex = -1;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxScore) {
          maxScore = probabilities[i];
          maxIndex = i;
        }
      }

      String resultText = "Index: $maxIndex";
      if (_labels != null && _labels!.isNotEmpty) {
        int labelIndex = maxIndex;
        if (labelIndex < _labels!.length) {
          resultText = _labels![labelIndex];
        }
      }

      // Giờ maxScore chắc chắn nằm trong khoảng 0.0 đến 1.0
      return "$resultText (${(maxScore * 100).toStringAsFixed(1)}%)";
    } catch (e) {
      print("❌ Lỗi khi predict: $e");
      return "Lỗi suy luận: $e";
    }
  }

  /// Hàm toán học để ép điểm số về phần trăm (0-1)
  List<double> _softmax(List<double> logits) {
    // 1. Tìm giá trị lớn nhất (để tránh tràn số khi tính mũ)
    double maxLogit = logits.reduce(max);

    // 2. Tính e^x cho từng phần tử
    List<double> exps = logits.map((x) => exp(x - maxLogit)).toList();

    // 3. Tính tổng các e^x
    double sumExps = exps.reduce((a, b) => a + b);

    // 4. Chia từng cái cho tổng để ra xác suất
    return exps.map((x) => x / sumExps).toList();
  }
}
