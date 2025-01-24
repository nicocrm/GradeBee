import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';

/// This Appwrite function will be executed whenever a note is created.
/// It will transcribe the note's audio into the text field and save it to the database.
/// The "isTranscribed" field will be set to true.
Future<dynamic> main(final context) async {
  try {
    final client = Client()
        .setEndpoint(
            Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
        .setProject(Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
        .setKey(context.req.headers['x-appwrite-key'] ?? '');
    final note = Note.fromJson(context.req.bodyJson);
    if (note.isTranscribed) {
      return context.res
          .json({'status': 'ignored', 'reason': 'Note is already transcribed'});
    }
    if (note.voice == null) {
      return context.res.json(
          {'status': 'ignored', 'reason': 'Note does not have a voice field'});
    }
    String text = "This is a transcribed note";
    await Databases(client).updateDocument(
        databaseId: Platform.environment['APPWRITE_DATABASE_ID']!,
        collectionId: "notes",
        documentId: note.id,
        data: {
          "is_transcribed": true,
          "text": text
          // "student_notes": studentNotes.map((e) => e.toJson()).toList()
        });

    return context.res.json({'status': 'success', 'text': text});
  } catch (e, s) {
    context.error('${e.toString()}\n$s');
    return context.res.json({
      'status': 'error',
      'message': e.toString(),
    });
  }
}
