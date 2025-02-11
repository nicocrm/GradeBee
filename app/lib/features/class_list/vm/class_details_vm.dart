import 'package:async/async.dart';
import 'package:flutter/material.dart';
import '../../../shared/ui/command.dart';
import '../models/class.model.dart';
import '../models/note.model.dart';
import '../models/pending_note.model.dart';
import '../models/student.model.dart';
import '../repositories/class_repository.dart';
import 'class_state_mixin.dart';

class ClassDetailsVM extends ChangeNotifier with ClassStateMixin {
  final ClassRepository _repository;
  final Class _initialClass;
  Class _class;
  late final Command0 updateClassCommand;
  late final Command1<Class, String> addVoiceNoteCommand;

  ClassDetailsVM(
    Class initialClass, [
    ClassRepository? repository,
  ])  : _repository = repository ?? ClassRepository(),
        _initialClass = initialClass,
        _class = initialClass {
    updateClassCommand = Command0(_updateClass);
    addVoiceNoteCommand = Command1(_addVoiceNote);
  }

  Class get currentClass => _class;
  Class get initialClass => _initialClass;

  Future<Class> getClassWithNotes() async {
    _class = await _repository.getClassWithNotes(_class);
    notifyListeners();
    return _class;
  }

  @override
  void setCourse(String course) {
    _class = _class.copyWith(course: course);
    notifyListeners();
  }

  @override
  void setDayOfWeek(String dayOfWeek) {
    _class = _class.copyWith(dayOfWeek: dayOfWeek);
    notifyListeners();
  }

  @override
  void setTimeBlock(String timeBlock) {
    _class = _class.copyWith(timeBlock: timeBlock);
    notifyListeners();
  }

  void addStudent(String student) {
    if (_class.students.any((s) => s.name == student)) {
      throw Exception('Student already exists');
    }
    _class = _class.copyWith(
      students: [..._class.students, Student(name: student)],
    );
    notifyListeners();
  }

  void removeStudent(String student) {
    _class = _class.copyWith(
      students: _class.students.where((s) => s.name != student).toList(),
    );
    notifyListeners();
  }

  void removeNote(Note note) {
    _class = _class.copyWith(
      notes: _class.notes.where((n) => n.id != note.id).toList(),
    );
    notifyListeners();
  }

  void removePendingNote(PendingNote pendingNote) {
    _class = _class.copyWith(
      pendingNotes: _class.pendingNotes.where((n) => n != pendingNote).toList(),
    );
    notifyListeners();
  }

  void playPendingNote(PendingNote pendingNote) {
    // TODO: Implement playPendingNote
  }

  Future<Result<Class>> _updateClass() async {
    try {
      _class = await _repository.updateClass(_class);
      return Result.value(_class);
    } catch (e) {
      return Result.error(Exception(e));
    }
  }

  Future<Result<Class>> _addVoiceNote(String recordingPath) async {
    try {
      _class = _class.copyWith(
        pendingNotes: [
          ..._class.pendingNotes,
          PendingNote(
            when: DateTime.now(),
            recordingPath: recordingPath,
          ),
        ],
      );
      _class = await _repository.updateClass(_class);
      return Result.value(_class);
    } catch (e) {
      return Result.error(Exception(e));
    }
  }
}
