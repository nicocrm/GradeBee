import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_function_helpers/helpers.dart';
import 'package:gradebee_models/common.dart';
import 'report_card_generator.dart';

class CreateReportCardRequest {
  final ReportCard reportCard;
  final String? feedback;

  CreateReportCardRequest(this.reportCard, [this.feedback]);
}

class CreateReportCardHandler {
  final SimpleLogger logger;
  final ReportCardGenerator generator;
  final DatabaseService database;

  CreateReportCardHandler(this.logger, this.generator, this.database);

  Future<CreateReportCardRequest> parseBody(Map<String, dynamic>? json) async {
    if (json == null) throw ValidationException("No body");
    final isRegenerate = json['regenerate'] == true;
    final hasFeedback = json['feedback'] != null;
    if (json['is_generated'] == true && !isRegenerate && !hasFeedback) {
      // this will be sent when we get the report card as a result of a record create
      throw ValidationException("Report card is already generated");
    }
    final reportCardId = json['\$id'];
    if (reportCardId == null) throw ValidationException("Missing \$id");
    final reportCard = await database.get<ReportCard>(
        "report_cards", ReportCard.fromJson, reportCardId,
        [
          Query.select(['*', 'sections.*', 'template.*', 'template.sections.*', 'student.*', 'student.notes.*'])
        ]);
    final feedback = hasFeedback ? json['feedback'] as String? : null;
    return CreateReportCardRequest(reportCard, feedback);
  }

  Future<ReportCard> processRequest(CreateReportCardRequest request) async {
    final reportCard = request.reportCard;
    try {
      final sections = await generator.generateReportCard(
          reportCard, feedback: request.feedback);
      reportCard.sections.clear();
      reportCard.sections.addAll(sections);
      reportCard.isGenerated = true;
      reportCard.error = null;
      logger.log(
          "Report card generated: ${reportCard.id} with sections: ${sections.join(", ")}");
    } catch (e, s) {
      logger.error("${e.toString()}\n$s");
      reportCard.error = "Error generating card";
      reportCard.isGenerated = false;
    }
    return reportCard;
  }

  Future<void> save(ReportCard output) async {
    await database.update(
        "report_cards",
        {
          "is_generated": output.isGenerated,
          "sections": output.sections.map((e) => e.toJson()).toList(),
          "error": output.error
        },
        output.id!);
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
