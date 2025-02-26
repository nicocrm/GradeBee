import '../../../shared/data/functions.dart';
import '../models/report_card.model.dart';

class ReportCardService {
  final FunctionService functions;

  ReportCardService({required this.functions});

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
            .toList());
  }
}
