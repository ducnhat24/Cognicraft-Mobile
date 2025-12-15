import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Thư viện chọn ảnh chuẩn
import 'package:gemini_chat_app/data/services/local_ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Model 1 lần duy nhất
  try {
    final aiService = LocalAIService();
    await aiService.loadModel();
    print("✅ AI Service Ready!");
  } catch (e) {
    print("❌ AI Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gemini AI R&D',
      home: AiTestScreen(),
    );
  }
}

class AiTestScreen extends StatefulWidget {
  const AiTestScreen({super.key});

  @override
  State<AiTestScreen> createState() => _AiTestScreenState();
}

class _AiTestScreenState extends State<AiTestScreen> {
  File? _selectedImage;
  String _result = "Chưa có kết quả";
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // Hàm chọn ảnh và đoán
  Future<void> _pickImage(ImageSource source) async {
    try {
      // 1. Chọn ảnh (Camera hoặc Thư viện)
      // Dùng ImagePicker sẽ gọi app Camera gốc của Android -> Ổn định hơn nhiều
      final XFile? photo = await _picker.pickImage(source: source);

      if (photo == null) return; // Người dùng hủy chọn

      setState(() {
        _selectedImage = File(photo.path);
        _isLoading = true;
        _result = "Đang phân tích...";
      });

      // 2. Gọi AI
      final aiService = LocalAIService();
      // Thêm delay giả vờ 1 xíu để thấy hiệu ứng loading (nếu máy chạy quá nhanh)
      await Future.delayed(const Duration(milliseconds: 500));

      final String prediction = await aiService.predictImage(photo.path);

      // 3. Cập nhật UI
      if (!mounted) return;
      setState(() {
        _result = prediction;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = "Lỗi: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MobileNet V3 Test")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hiển thị ảnh đã chọn
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 200,
                  width: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 100, color: Colors.grey),
                ),

              const SizedBox(height: 20),

              // Hiển thị kết quả Loading hoặc Text
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _result,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // Hai nút chức năng
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Chụp Ảnh"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Thư Viện"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
