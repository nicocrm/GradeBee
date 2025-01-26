import 'dart:async';
import 'package:gradebee_models/common.dart';

import 'transcribe_note_handler.dart';

/// This Appwrite function will be executed whenever a note is created.
/// It will transcribe the note's audio into the text field and save it to the database.
/// The "isTranscribed" field will be set to true.
Future<dynamic> main(final context) async {
  try {
    final handler = TranscribeNoteHandler(context);
    final input = handler.parseBody(context.req.bodyJson);
    final output = await handler.processRequest(input);
    await handler.save(output);
    return context.res.json(handler.result(output));
  } on ValidationException catch (e) {
    return context.res.json({"status": "ignored", "message": e.toString()});
  } catch (e, s) {
    context.error('${e.toString()}\n$s');
    return context.res.json({
      'status': 'error',
      'message': e.toString(),
    });
  }
}
