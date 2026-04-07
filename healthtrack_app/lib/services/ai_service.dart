import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AiService {
  // Replace with your LLM endpoint and API key
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _apiKey   = 'YOUR_API_KEY_HERE'; // → use flutter_dotenv in production

  // Returns a short motivational health tip personalized to the user
  static Future<String> getHealthInsight(UserModel user) async {
    final prompt = '''
You are a friendly health coach. Given this user's stats, write ONE short 
motivational tip (max 2 sentences). Be specific and positive.

User:
- Name: ${user.name}
- Goal: ${user.goal}
- Streak: ${user.streak} days
- Current weight: ${user.currentWeight} kg
- Target weight: ${user.targetWeight} kg
- Health score: ${user.healthScore.toStringAsFixed(0)}%
- BMI: ${user.bmi.toStringAsFixed(1)}
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model':       'gpt-4o-mini',
          'max_tokens':  120,
          'messages':    [{'role': 'user', 'content': prompt}],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      }
      return 'Keep going — consistency is the key to results!';
    } catch (_) {
      return 'Every healthy choice counts. You are doing great!';
    }
  }
}