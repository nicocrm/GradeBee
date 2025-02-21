import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';
import 'create_report_card_handler.dart';
import 'report_card_generator.dart';
import 'package:gradebee_function_helpers/helpers.dart';

/// This Appwrite function will be executed whenever a note is created or updated with a "text" field.
/// It will split the note into individual notes for each student and save them to the database.
/// The "isSplit" field will be set to true.
Future<dynamic> main(final context) async {
  final logger = setupLogging('create-report-card', context);
  try {
    final client = Client()
        .setEndpoint(
            Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
        .setProject(Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
        .setKey(context.req.headers['x-appwrite-key'] ?? '');

    final generator =
        ReportCardGenerator(Platform.environment['OPENAI_API_KEY']!);
    final handler = CreateReportCardHandler(logger, generator, client);
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
