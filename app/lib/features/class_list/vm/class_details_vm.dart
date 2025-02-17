import 'package:async/async.dart';
import 'package:flutter/material.dart';
import '../../../shared/ui/command.dart';
import '../models/class.model.dart';
import '../models/student.model.dart';
import '../repositories/class_repository.dart';
import 'class_state_mixin.dart';

class ClassDetailsVM extends ChangeNotifier with ClassStateMixin {
  final ClassRepository _repository;
  final Class _initialClass;
  Class _class;
  late final Command0 updateClassCommand;

  ClassDetailsVM(
    Class initialClass, [
    ClassRepository? repository,
  ])  : _repository = repository ?? ClassRepository(),
        _initialClass = initialClass,
        _class = initialClass {
    updateClassCommand = Command0(_updateClass);
  }

  Class get currentClass => _class;
  Class get initialClass => _initialClass;

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
  void setRoom(String room) {
    _class = _class.copyWith(room: room);
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

  Future<Result<Class>> _updateClass() async {
    try {
      _class = await _repository.updateClass(_class);
      return Result.value(_class);
    } catch (e) {
      return Result.error(Exception(e));
    }
  }
}
