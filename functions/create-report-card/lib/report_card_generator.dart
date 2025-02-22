import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:gradebee_models/common.dart';
import 'package:gradebee_function_helpers/helpers.dart';

class ReportCardGenerator {
  final SimpleLogger logger;
  ReportCardGenerator(this.logger, String apiKey) {
    OpenAI.apiKey = apiKey;
  }

  Future<List<ReportCardSection>> generateReportCard(
      ReportCard reportCard) async {
    final systemPrompt = createSystemPrompt(reportCard.template.sections);
    final prompt =
        createUserPrompt(reportCard.studentNotes, reportCard.student.name);
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
    final json = content[0].text!;
    logger.log("Generated report card: $json");
    final sections = jsonDecode(json);
    final List<ReportCardSection> reportCardSections = [];
    for (var section in sections) {
      reportCardSections.add(ReportCardSection(
        category: section['category'],
        text: section['content'],
      ));
    }
    return reportCardSections;
  }

  createUserPrompt(List<String> studentNotes, String studentName) {
    return '''
This is the student name: $studentName
This is the list of student notes:
${studentNotes.join("\n-------------\n\n\n")}
''';
  }

  createSystemPrompt(List<ReportCardTemplateSection> sections) {
    return '''
You are a helpful assistant that generates report cards.

You will be given a student name, a list of student notes, and a template for the report card.

You will need to generate a report card for each student based on the notes and the template.

The template will have a list of categories, each with a category title, and a list of examples.
They will be provided as a list of JSON objects with the following fields:
- category: the title of the category
- examples: a list of examples

The notes will be provided as free-form text, each note separated by a line of dashes.

The student name will be provided as a string.

Requirements:
- use the same categories as the template with the same titles
- use only the following categories: ${sections.map((e) => e.category).join(", ")}
- Ensure each report is tailored to the student's notes while maintaining the tone and style of the template.
- Keep similar length to examples
- Don't get too creative, keep it professional
- Stay factual and don't invent information
- Don't use newlines or bullets
- Maximum 400 characters
- Use British English
- If no information is available for a category, omit it from the output.
- Use the provided student name
- Don't mention absence
- Be specific

Format the response as a JSON array without including any code block delimiters where each object has:
- category: the title of the category,
- content: the content of the category.

This is the template with the categories and examples:
${jsonEncode(sections)}
''';
  }
}
