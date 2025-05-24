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
  late final Command2<void, String, String> updateNoteCommand;
  late final Command1<void, String> deleteNoteCommand;
  late final Command1<void, DateTimeRange> addReportCardCommand;

  StudentDetailsVM(this.studentId,
      {required this.repository, required this.reportCardService}) {
    generateReportCardCommand = Command1(_generateReportCard);
    addNoteCommand = Command1(_addNote);
    updateNoteCommand = Command2(_updateNote);
    deleteNoteCommand = Command1(_deleteNote);
    addReportCardCommand = Command1(_addReportCard);
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
    final newStudent = _student!.addNote(note);
    await _updateStudent(newStudent);
    await loadStudent();
    notifyListeners();
    return Result.value(null);
  }

  Future<Result<void>> _updateNote(String noteId, String newText) async {
    final newStudent = _student!.updateNote(noteId, newText);
    await _updateStudent(newStudent);
    notifyListeners();
    return Result.value(null);
  }

  Future<Result<void>> _deleteNote(String noteId) async {
    final newStudent = _student!.deleteNote(noteId);
    await _updateStudent(newStudent);
    notifyListeners();
    return Result.value(null);
  }

  Future<Result<void>> _addReportCard(DateTimeRange period) async {
    final reportCard = ReportCard(
      when: DateTime.now(),
      sections: [],
    );
    final newStudent = _student!.addReportCard(reportCard);
    await _updateStudent(newStudent);
    notifyListeners();
    return Result.value(null);
  }

  Future<void> _updateStudent(Student student) async {
    try {
      await repository.updateStudent(student);
      _student = student;
    } catch (e) {
      rethrow;
    }
    notifyListeners();
  }
}
