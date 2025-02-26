import 'package:gradebee_function_helpers/helpers.dart';
import 'package:gradebee_models/common.dart';
import 'report_card_generator.dart';

class CreateReportCardHandler {
  final SimpleLogger logger;
  final ReportCardGenerator generator;
  final DatabaseService database;

  CreateReportCardHandler(this.logger, this.generator, this.database);

  Future<ReportCard> parseBody(Map<String, dynamic>? json) async {
    if (json == null) throw ValidationException("No body");
    if (json['is_generated'] == true) {
      // this will be sent when we get the report card as a result of a record create
      throw ValidationException("Report card is already generated");
    }
    final reportCardId = json['\$id'];
    final reportCard = await database.get<ReportCard>(
        "report_cards", ReportCard.fromJson, reportCardId);
    return reportCard;
  }

  Future<ReportCard> processRequest(ReportCard reportCard) async {
    try {
      final sections = await generator.generateReportCard(reportCard);
      reportCard.sections.clear();
      reportCard.sections.addAll(sections);
      reportCard.isGenerated = true;
      reportCard.error = null;
      logger.log(
          "Report card generated: ${reportCard.id} with sections: ${sections.join(", ")}");
    } catch (e, s) {
      logger.error("${e.toString()}\n$s");
      reportCard.error = "Error splitting notes";
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
