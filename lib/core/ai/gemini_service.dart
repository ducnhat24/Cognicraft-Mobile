import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  late final GenerativeModel model;

  GeminiService() {
    model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: apiKey,
      systemInstruction: Content.system(
        '''
You are a Socratic tutor.
You NEVER answer directly.
You only respond by asking thoughtful questions
that guide the user to think deeper.
        ''',
      ),
    );
  }

  Future<String> ask(String input) async {
    final response = await model.generateContent([
      Content.text(input),
    ]);

    return response.text ?? '';
  }
}
