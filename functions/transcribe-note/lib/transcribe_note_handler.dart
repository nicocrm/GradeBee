import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';
import 'bucket.dart';
import 'speechtotext.dart';

class TranscribeNoteHandler {
  final Client client;
  late final Bucket bucket;
  final dynamic context;

  TranscribeNoteHandler(this.context)
      : client = Client()
            .setEndpoint(
                Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
            .setProject(
                Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
            .setKey(context.req.headers['x-appwrite-key'] ?? '') {
    bucket = Bucket(client, Platform.environment['NOTES_BUCKET_ID']!);
  }

  Note parseBody(Map<String, dynamic>? json) {
    if (json == null) throw ValidationException("No body");
    final note = Note.fromJson(json);
    if (note.isTranscribed) {
      throw ValidationException("Note is already transcribed");
    }
    if (note.voice == null) {
      throw ValidationException("Note does not have a voice field");
    }
    return note;
  }

  Future<Note> processRequest(Note note) async {
    try {
      final students = note.class_.students.map((s) => s.name).toList();
      final audio = await bucket.download(note.voice!, context);
      note.text =
          await Speechtotext(Platform.environment['OPENAI_API_KEY'] ?? '')
              .transcribe(students, audio);
    } catch (e, s) {
      context.error("${e.toString()}\n$s");
      note.error = "Error transcribing notes";
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
          "is_transcribed": output.isTranscribed,
          "text": output.text,
          "error": output.error
        });
  }

  Map<String, dynamic> result(Note output) {
    if (output.error != null) {
      return {"status": "error", "message": output.error};
    }
    return {"status": "success", "text": output.text};
  }
}
