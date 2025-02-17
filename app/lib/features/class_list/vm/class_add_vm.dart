import 'package:flutter/foundation.dart';
import '../models/class.model.dart';
import '../repositories/class_repository.dart';
import 'class_state_mixin.dart';

class ClassAddVM extends ChangeNotifier with ClassStateMixin {
  final ClassRepository _repository;
  Class _currentClass = Class(course: '', dayOfWeek: null, room: '');

  ClassAddVM([ClassRepository? repository])
      : _repository = repository ?? ClassRepository();

  Class get currentClass => _currentClass;

  @override
  void setCourse(String course) {
    _currentClass = _currentClass.copyWith(course: course);
    notifyListeners();
  }

  @override
  void setDayOfWeek(String dayOfWeek) {
    _currentClass = _currentClass.copyWith(dayOfWeek: dayOfWeek);
    notifyListeners();
  }

  @override
  void setRoom(String room) {
    _currentClass = _currentClass.copyWith(room: room);
    notifyListeners();
  }

  Future<Class?> addClass() async {
    _currentClass = await _repository.addClass(_currentClass);
    notifyListeners();
    return _currentClass;
  }
}
