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
  late final Command1<void, String> addNoteCommand;

  StudentDetailsVM(this.studentId,
      {required this.repository, required this.reportCardService}) {
    generateReportCardCommand = Command1(_generateReportCard);
    addNoteCommand = Command1(_addNote);
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

  Future<Result<void>> _addNote(String note) async {
    _student = _student!.addNote(note);
    await repository.updateStudent(_student!);
    notifyListeners();
    return Result.value(null);
  }
}
