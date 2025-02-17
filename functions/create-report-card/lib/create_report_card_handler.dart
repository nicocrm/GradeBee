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

  ReportCard parseBody(Map<String, dynamic>? json) {
    if (json == null) throw ValidationException("No body");
    final reportCard = ReportCard.fromJson(json);
    if (reportCard.isGenerated) {
      throw ValidationException("Note is already split");
    }
    return reportCard;
  }

  Future<ReportCard> processRequest(ReportCard reportCard) async {
    try {
      final generator =
          ReportCardGenerator(Platform.environment['OPENAI_API_KEY']!);
      reportCard = await generator.generateReportCard(reportCard);
      reportCard.isGenerated = true;
      reportCard.error = null;
    } catch (e, s) {
      context.error("${e.toString()}\n$s");
      reportCard.error = "Error splitting notes";
      reportCard.isGenerated = false;
    }
    return reportCard;
  }

  Future<void> save(ReportCard output) async {
    await Databases(client).updateDocument(
        databaseId: Platform.environment['APPWRITE_DATABASE_ID']!,
        collectionId: "notes",
        documentId: output.id,
        data: {
          "is_generated": output.isGenerated,
          "sections": output.sections.map((e) => e.toJson()).toList(),
          "error": output.error
        });
  }

  Map<String, dynamic> result(ReportCard output) {
    if (output.error != null) {
      return {"status": "error", "message": output.error};
    }
    return {
      "status": "success",
      "sections": output.sections.map((e) => e.toJson()).toList()
    };
  }
}
