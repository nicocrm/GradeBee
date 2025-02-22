import 'package:args/args.dart';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_function_helpers/helpers.dart';
import 'package:gradebee_models/common.dart';
import 'package:dotenv/dotenv.dart';

import 'create_report_card_handler.dart';
import 'report_card_generator.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Show this help message')
    ..addOption('student',
        abbr: 's', help: 'The student id to create a report card for')
    ..addOption('template',
        abbr: 't', help: 'The template id to use for the report card');
  final logger = setupLogging('create-report-card');

  final env = DotEnv()..load(['../.env']);

  final results = parser.parse(args);

  if (results['help'] as bool) {
    logger.log(parser.usage);
    return;
  }

  if (results['student'] == null) {
    logger.error('Student id is required');
    return;
  }

  if (results['template'] == null) {
    logger.error('Template id is required');
    return;
  }

  try {
    final client = Client()
        .setEndpoint(env['APPWRITE_ENDPOINT'] ?? '')
        .setProject(env['APPWRITE_PROJECT_ID'] ?? '')
        .setKey(env['APPWRITE_API_KEY'] ?? '');

    final generator = ReportCardGenerator(logger, env['OPENAI_API_KEY'] ?? '');
    final handler = CreateReportCardHandler(logger, generator, client);
    final database = DatabaseService(client, env['APPWRITE_DATABASE_ID'] ?? '');
    final source = await initializeReportCard(
        database, results['student'], results['template']);

    final processed = await handler.processRequest(source);
    if (processed.isGenerated) {
      final insertedId =
          await database.insert('report_cards', processed.toJson());
      logger.log("Processed report card $insertedId");
    } else {
      logger.error('Failed to generate report card');
    }
  } catch (e, s) {
    logger.error('Error creating report card', e, s);
  }
}

Future<ReportCard> initializeReportCard(
    DatabaseService database, String studentId, String templateId) async {
  print(
      'initializing report card for student $studentId and template $templateId');
  final student = await database.get('students', Student.fromJson, studentId);
  final template = await database.get(
      'report_card_templates', ReportCardTemplate.fromJson, templateId);
  final studentNotes =
      await database.list('student_notes', (x) => (x['text'] as String), [
    Query.equal('student', studentId),
    Query.select(['text'])
  ]);
  // delete existing report cards for this student / template, if present
  final existingReportCard =
      await database.list('report_cards', (x) => (x["\$id"] as String), [
    Query.equal('student', studentId),
    Query.equal('template', templateId),
    Query.select(['\$id'])
  ]);
  if (existingReportCard.isNotEmpty) {
    for (final existingId in existingReportCard) {
      await database.delete('report_cards', existingId);
    }
  }
  // and return a new one
  final reportCard = ReportCard(
    when: DateTime.now(),
    sections: [],
    template: template,
    student: student,
    studentNotes: studentNotes,
  );
  return reportCard;
}
