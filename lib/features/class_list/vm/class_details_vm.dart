import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/student.model.dart';
import '../repositories/class_repository.dart';
import 'class_state_mixin.dart';

import '../models/class.model.dart';
part 'class_details_vm.g.dart';

@riverpod
class ClassDetailsVm extends _$ClassDetailsVm with ClassStateMixin {
  late final Class _origin;

  @override
  Class build(Class originClass) {
    _origin = originClass;
    return originClass;
  }

  @override
  void setCourse(String course) {
    state = state.copyWith(course: course);
  }

  @override
  void setDayOfWeek(String dayOfWeek) {
    state = state.copyWith(dayOfWeek: dayOfWeek);
  }

  @override
  void setRoom(String room) {
    state = state.copyWith(room: room);
  }

  void addStudent(String student) {
    if (state.students.any((s) => s.name == student)) {
      throw Exception('Student already exists');
    }
    state =
        state.copyWith(students: [...state.students, Student(name: student)]);
  }

  void removeStudent(String student) {
    state = state.copyWith(
        students: state.students.where((s) => s.name != student).toList());
  }

  Future<void> updateClass() async {
    await ref.read(classRepositoryProvider).updateClass(state);
  }
}
