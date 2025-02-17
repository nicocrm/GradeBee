import 'dart:async';
import 'package:gradebee_models/common.dart';
import 'create_report_card_handler.dart';

/// This Appwrite function will be executed whenever a note is created or updated with a "text" field.
/// It will split the note into individual notes for each student and save them to the database.
/// The "isSplit" field will be set to true.
Future<dynamic> main(final context) async {
  try {
    final handler = CreateReportCardHandler(context);
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
