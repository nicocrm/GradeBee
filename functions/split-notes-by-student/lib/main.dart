import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';
import 'openai.dart';

/// This Appwrite function will be executed whenever a note is created.
/// It will split the note into individual notes for each student and save them to the database.
Future<dynamic> main(final context) async {
  final client = Client()
      .setEndpoint(Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
      .setProject(Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
      .setKey(context.req.headers['x-appwrite-key'] ?? '');
  final body = context.req.bodyJson;
  context.log("HEADERS");
  context.log(context.req.headers);
  context.log("Event: " + (context.req.headers["x-appwrite-event"] ?? ''));
  context.log(body);
  final openai = OpenAI(Platform.environment['OPENAI_API_KEY'] ?? '');
  final note = Note.fromJson(context.req.bodyJson);
  final studentNotes = await openai.splitNotesByStudent(note);
  Databases(client).updateDocument(
      databaseId: "notes",
      collectionId: "notes",
      documentId: note.id,
      data: {"student_notes": studentNotes.map((e) => e.toJson()).toList()});

  return context.res.json({
    'status': 'success',
    'student_notes': studentNotes.map((e) => e.toJson()).toList()
  });
}
