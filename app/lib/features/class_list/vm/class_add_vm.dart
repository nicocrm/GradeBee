import 'package:flutter/foundation.dart';
import '../models/class.model.dart';
import '../repositories/class_repository.dart';
import 'class_state_mixin.dart';

class ClassAddVM extends ChangeNotifier with ClassStateMixin {
  final ClassRepository _repository;
  Class _currentClass =
      Class(course: '', dayOfWeek: null, timeBlock: '', schoolYear: '');

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
  void setTimeBlock(String time) {
    _currentClass = _currentClass.copyWith(timeBlock: time);
    notifyListeners();
  }

  @override
  void setSchoolYear(String schoolYear) {
    _currentClass = _currentClass.copyWith(schoolYear: schoolYear);
    notifyListeners();
  }

  Future<Class?> addClass() async {
    _currentClass = await _repository.addClass(_currentClass);
    notifyListeners();
    return _currentClass;
  }
}
