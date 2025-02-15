import 'package:dart_openai/dart_openai.dart';
import 'package:gradebee_models/common.dart';

class ReportCardGenerator {
  ReportCardGenerator(String apiKey) {
    OpenAI.apiKey = apiKey;
  }

  Future<ReportCard> generateReportCard(ReportCard reportCard) async {
    final response = await OpenAI.instance.chat.create(
      model: "gpt-4o-mini",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: "You are a helpful assistant that generates report cards.",
        ),
      ],
    );
  }
}
