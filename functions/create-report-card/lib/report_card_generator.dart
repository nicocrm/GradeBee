import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:gradebee_models/common.dart';

class ReportCardGenerator {
  ReportCardGenerator(String apiKey) {
    OpenAI.apiKey = apiKey;
  }

  Future<List<ReportCardSection>> generateReportCard(
      ReportCard reportCard) async {
    final systemPrompt = createSystemPrompt(reportCard.template);
    final prompt = createUserPrompt(reportCard.studentNotes);
    final response = await OpenAI.instance.chat.create(
      model: "gpt-4o-mini",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                systemPrompt),
          ],
        ),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
          ],
        ),
      ],
    );
    final content = response.choices.first.message.content;
    if (content == null || content[0].text == null) {
      throw Exception('Failed to generate report card');
    }
    final sections = jsonDecode(content[0].text!);
    final List<ReportCardSection> reportCardSections = [];
    for (var section in sections) {
      reportCardSections.add(ReportCardSection(
        category: section['category'],
        text: section['text'],
      ));
    }
    return reportCardSections;
  }

  createUserPrompt(List<String> studentNotes) {
    return '''
This is the list of student notes:
${studentNotes.join("\n-------------\n\n")}
''';
  }

  createSystemPrompt(ReportCardTemplate template) {
    return '''
You are a helpful assistant that generates report cards.

You will be given a list of student notes and a template for the report card.

You will need to generate a report card for each student based on the notes and the template.

The template will have a list of sections, each with a title, and a list of examples.

The report card generated will have the same sections as the template with the same titles.

The report card generated will be in the same language as the notes.

The report card generated will be in the same style as the examples.

The report card generated will be in the same tone as the examples.

The report card generated will be in the same structure as the examples.

The report card generated will be in the same level of detail as the examples.

The report card generated should be returned as a JSON array of objects, each object will have the following fields:
- section: the title of the section
- content: the content of the section

This is the template with the sections and examples:
${template.toJson()}
''';
  }
}
