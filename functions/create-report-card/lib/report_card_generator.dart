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
      ReportCard reportCard, {String? feedback}) async {
    final hasFeedback = feedback != null && feedback.isNotEmpty;
    final systemPrompt = createSystemPrompt(reportCard.template.sections,
        isRegeneration: hasFeedback);
    final prompt = createUserPrompt(
        reportCard.studentNotes, reportCard.student.name,
        currentDraft: hasFeedback ? reportCard.sections : null,
        feedback: feedback);
    logger.log("System prompt: $systemPrompt");
    logger.log("User prompt: $prompt");
    final response = await OpenAI.instance.chat.create(
      model: "gpt-5.2",
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
    logger.log("Generated report card (updated): $json");
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

  createUserPrompt(List<String> studentNotes, String studentName,
      {List<ReportCardSection>? currentDraft, String? feedback}) {
    var prompt = '''
This is the student name: $studentName
This is the list of student notes:
${studentNotes.join("\n-------------\n\n\n")}
''';
    if (currentDraft != null &&
        currentDraft.isNotEmpty &&
        feedback != null &&
        feedback.isNotEmpty) {
      prompt += '''

Current draft of the report card:
${jsonEncode(currentDraft.map((s) => {'category': s.category, 'content': s.text}).toList())}

Feedback from the teacher: $feedback
Please revise the report card based on this feedback while keeping the same structure and format.
''';
    }
    return prompt;
  }

  createSystemPrompt(List<ReportCardTemplateSection> sections,
      {bool isRegeneration = false}) {
    return '''
You are a helpful assistant that generates report cards.

You will be given a student name, a list of student notes, and a template for the report card.
${isRegeneration ? 'You may also be given a current draft and feedback from the teacher. In that case, revise the report card accordingly.' : ''}

You will need to generate a report card for each student based on the notes and the template.

The template will have a list of categories, each with a category title, and a list of examples.
They will be provided as a list of JSON objects with the following fields:
- category: the title of the category
- special_instructions: any special instructions for the category, overriding default instructions
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
- Mininum 350 characters
- Maximum 420 characters
- If the generated text is over 450 characters, summarize it down to 450 characters max
- Use British English
- Use the provided student name
- Don't mention absence
- Be specific

Format the response as a JSON array without including any code block delimiters where each object has:
- category: the title of the category,
- content: the content of the category.

This is the template with the categories and examples:
${jsonEncode(sections.map((e) => e.toJson()).toList())}
''';
  }
}
