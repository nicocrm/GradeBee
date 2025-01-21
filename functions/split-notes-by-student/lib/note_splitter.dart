import 'dart:convert';

import 'package:gradebee_models/common.dart';
import 'package:dart_openai/dart_openai.dart';

class NoteSplitter {
  NoteSplitter(String apiKey) {
    OpenAI.apiKey = apiKey;
  }

  Stream<StudentNote> splitNotesByStudent(Note note) async* {
    Map<String, Student> studentsByName = {
      for (var student in note.class_.students) student.name: student
    };
    final prompt = '''
              Split the following teacher's note into individual student notes.

              Format the response as a JSON array without including any code block delimiters where each object has: studentName: the student\'s name, content: the content relevant to that student.
              Use the following student names:
              ${studentsByName.keys.join(", ")}

              If a student in the note is not in the above list, do not create a note for that student.
              For each student mentioned, create a separate note with only the information relevant to that student.
              If a student is mentioned multiple times, create one combined note for that student.
              If a student is not mentioned, do not create a note for that student.
              Be precise.

              Teacher's note:
              ${note.text}
              ''';
    try {
      final userMessage = OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)
          ]);
      final chatCompletion = await OpenAI.instance.chat.create(
        model: 'gpt-4o',
        messages: [userMessage],
      );

      final content = chatCompletion.choices.first.message.content;
      if (content == null || content[0].text == null) {
        throw Exception('Failed to split notes');
      }
      final List<dynamic> splitNotes = jsonDecode(content[0].text!);
      for (var noteData in splitNotes) {
        final studentName = noteData['studentName'];
        final content = noteData['content'];
        final student = studentsByName[studentName];
        if (student != null) {
          yield StudentNote(student: student, text: content, when: note.when);
        }
      }
    } catch (e) {
      throw Exception('Failed to split notes: $e');
    }
  }
}
