import 'package:async/async.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/command.dart';
import '../models/report_card.model.dart';
import '../models/student.model.dart';
import '../repositories/student_repository.dart';
import '../services/report_card_service.dart';

class StudentDetailsVM extends ChangeNotifier {
  final String studentId;
  final StudentRepository repository;
  final ReportCardService reportCardService;
  Student? _student;
  late final Command1<void, ReportCard> generateReportCardCommand;

  StudentDetailsVM(this.studentId,
      {required this.repository, required this.reportCardService}) {
    generateReportCardCommand = Command1(_generateReportCard);
  }

  Student get student => _student!;

  Future<Student> loadStudent() async {
    _student = await repository.getStudent(studentId);
    return _student!;
  }

  Future<Result<void>> _generateReportCard(ReportCard reportCard) async {
    reportCard = await reportCardService.generateReportCard(reportCard);
    _student = _student!.updateReportCard(reportCard);
    notifyListeners();
    return Result.value(null);
  }
}
