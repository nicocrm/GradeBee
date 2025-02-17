import 'package:flutter/foundation.dart';
import '../../../data/services/database.dart';
import '../models/class.model.dart';
import 'class_state_mixin.dart';

class ClassAddVM extends ChangeNotifier with ClassStateMixin {
  final Database _db;
  Class _currentClass;

  ClassAddVM([Database? db])
      : _db = db ?? Database(),
        _currentClass = Class(course: '', dayOfWeek: null, room: '');

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
    final id = await _db.insert('classes', _currentClass.toJson());
    _currentClass = _currentClass.copyWith(id: id);
    notifyListeners();
    return _currentClass;
  }
}
