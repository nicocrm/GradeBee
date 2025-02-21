import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_function_helpers/helpers.dart';
import 'package:gradebee_models/common.dart';
import 'report_card_generator.dart';

class CreateReportCardHandler {
  final Client client;
  final SimpleLogger logger;
  final ReportCardGenerator generator;

  CreateReportCardHandler(this.logger, this.generator, this.client);

  ReportCard parseBody(Map<String, dynamic>? json) {
    if (json == null) throw ValidationException("No body");
    final reportCard = ReportCard.fromJson(json);
    if (reportCard.isGenerated) {
      throw ValidationException("Report card is already generated");
    }
    return reportCard;
  }

  Future<ReportCard> processRequest(ReportCard reportCard) async {
    try {
      final sections = await generator.generateReportCard(reportCard);
      reportCard.sections.clear();
      reportCard.sections.addAll(sections);
      reportCard.isGenerated = true;
      reportCard.error = null;
    } catch (e, s) {
      logger.error("${e.toString()}\n$s");
      reportCard.error = "Error splitting notes";
      reportCard.isGenerated = false;
    }
    return reportCard;
  }

  Future<void> save(ReportCard output) async {
    await Databases(client).updateDocument(
        databaseId: Platform.environment['APPWRITE_DATABASE_ID']!,
        collectionId: "notes",
        documentId: output.id!,
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
