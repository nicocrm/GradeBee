import '../../../shared/data/database.dart';
import '../../../shared/data/functions.dart';
import '../models/report_card.model.dart';
import '../models/report_card_template.model.dart';

class ReportCardService {
  final FunctionService functions;
  final DatabaseService database;

  ReportCardService({required this.functions, required this.database});

  Future<String> getDefaultTemplate() async {
    final templates = await database.list(
        'report_card_templates', ReportCardTemplate.fromJson);
    return templates.first.id;
  }

  Future<ReportCard> generateReportCard(ReportCard reportCard) async {
    final response =
        await functions.execute('create-report-card', {"\$id": reportCard.id});
    if (response['status'] == 'error') {
      throw Exception(response['message']);
    }
    return reportCard.copyWith(
        isGenerated: true,
        sections: (response['sections'] as List)
            .map((e) => ReportCardSection.fromJson(e))
            .toList(),
        wasModified: false);
  }
}
