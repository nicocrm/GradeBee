import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';
import 'report_card_generator.dart';

class CreateReportCardHandler {
  final Client client;
  final dynamic context;

  CreateReportCardHandler(this.context)
      : client = Client()
            .setEndpoint(
                Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
            .setProject(
                Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
            .setKey(context.req.headers['x-appwrite-key'] ?? '');

  Note parseBody(Map<String, dynamic>? json) {
    if (json == null) throw ValidationException("No body");
    final note = Note.fromJson(json);
    if (note.isSplit) throw ValidationException("Note is already split");
    if (note.text == null) {
      throw ValidationException("Note does not have a text field");
    }
    return note;
  }

  Future<Note> processRequest(Note note) async {
    try {
      final splitter =
          NoteSplitter(Platform.environment['OPENAI_API_KEY'] ?? '');
      note.studentNotes = await splitter.splitNotesByStudent(note).toList();
      note.isSplit = true;
      note.error = null;
    } catch (e, s) {
      context.error("${e.toString()}\n${s}");
      note.error = "Error splitting notes";
      note.isSplit = false;
    }
    return note;
  }

  Future<void> save(Note output) async {
    await Databases(client).updateDocument(
        databaseId: Platform.environment['APPWRITE_DATABASE_ID']!,
        collectionId: "notes",
        documentId: output.id,
        data: {
          "is_split": output.isSplit,
          "student_notes": output.studentNotes.map((e) => e.toJson()).toList(),
          "error": output.error
        });
  }

  Map<String, dynamic> result(Note output) {
    if (output.error != null) {
      return {"status": "error", "message": output.error};
    }
    return {
      "status": "success",
      "studentNotes": output.studentNotes.map((e) => e.toJson()).toList()
    };
  }
}
