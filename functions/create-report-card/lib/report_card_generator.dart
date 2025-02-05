import 'package:dart_openai/dart_openai.dart';

class ReportCardGenerator {
  ReportCardGenerator(String apiKey) {
    OpenAI.apiKey = apiKey;
  }
}
