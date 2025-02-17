import '../models/class.model.dart';

abstract class ClassState {
  Class get class_;
}

mixin ClassStateMixin<T extends ClassState> {
  void setCourse(String course);
  void setDayOfWeek(String dayOfWeek);
  void setRoom(String room);
}