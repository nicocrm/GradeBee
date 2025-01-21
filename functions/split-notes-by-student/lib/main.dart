import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';
import 'note_splitter.dart';

/// This Appwrite function will be executed whenever a note is created.
/// It will split the note into individual notes for each student and save them to the database.
Future<dynamic> main(final context) async {
  try {
    final client = Client()
        .setEndpoint(
            Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
        .setProject(Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
        .setKey(context.req.headers['x-appwrite-key'] ?? '');
    final note = Note.fromJson(context.req.bodyJson);
    final splitter = NoteSplitter(Platform.environment['OPENAI_API_KEY'] ?? '');
    final studentNotes = await splitter.splitNotesByStudent(note).toList();
    await Databases(client).updateDocument(
        databaseId: Platform.environment['APPWRITE_DATABASE_ID']!,
        collectionId: "notes",
        documentId: note.id,
        data: {
          "is_split": true,
          "student_notes": studentNotes.map((e) => e.toJson()).toList()
        });

    return context.res.json({
      'status': 'success',
      'student_notes': studentNotes.map((e) => e.toJson()).toList()
    });
  } catch (e, s) {
    context.error('${e.toString()}\n$s');
    return context.res.json({
      'status': 'error',
      'message': e.toString(),
    });
  }
}
