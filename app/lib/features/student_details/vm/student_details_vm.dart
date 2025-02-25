import 'package:async/async.dart';

import '../../../shared/ui/command.dart';
import '../models/report_card.model.dart';
import '../models/student.model.dart';
import '../repositories/student_repository.dart';

class StudentDetailsVM {
  final String studentId;
  final StudentRepository _repository;
  late final Command1<void, ReportCard> generateReportCardCommand;

  StudentDetailsVM(this.studentId, [StudentRepository? repository])
      : _repository = repository ?? StudentRepository() {
    generateReportCardCommand = Command1(_generateReportCard);
  }

  Future<Student> getStudent() async {
    return _repository.getStudent(studentId);
  }

  Future<Result<void>> _generateReportCard(ReportCard reportCard) async {
    reportCard.isGenerated = false;
    await _repository.updateReportCard(reportCard);
    return Result.value(null);
  }
}
