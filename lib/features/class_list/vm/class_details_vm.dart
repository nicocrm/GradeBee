import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/student.model.dart';
import '../repositories/class_repository.dart';
import 'class_state_mixin.dart';

import '../models/class.model.dart';
part 'class_details_vm.freezed.dart';
part 'class_details_vm.g.dart';

@freezed
class ClassDetailsState extends ClassState with _$ClassDetailsState {
  factory ClassDetailsState({
    required Class class_,
    required bool isLoading,
    @Default(false) bool hasChanges,
    @Default('') String error,
  }) = _ClassDetailsState;
}

@riverpod
class ClassDetailsVm extends _$ClassDetailsVm
    with ClassStateMixin<ClassDetailsState> {
  late final ClassRepository _repo;

  @override
  ClassDetailsState build(Class originClass) {
    _repo = ref.watch(classRepositoryProvider);
    return ClassDetailsState(
      class_: originClass,
      isLoading: false,
    );
  }

  @override
  void setCourse(String course) {
    state = state.copyWith(
        hasChanges: true, class_: state.class_.copyWith(course: course));
  }

  @override
  void setDayOfWeek(String dayOfWeek) {
    state = state.copyWith(
        hasChanges: true, class_: state.class_.copyWith(dayOfWeek: dayOfWeek));
  }

  @override
  void setRoom(String room) {
    state = state.copyWith(
        hasChanges: true, class_: state.class_.copyWith(room: room));
  }

  void addStudent(String student) {
    if (state.class_.students.any((s) => s.name == student)) {
      state = state.copyWith(error: 'Student already exists');
      return;
    }
    state = state.copyWith(
        hasChanges: true,
        class_: state.class_.copyWith(
            students: [...state.class_.students, Student(name: student)]));
  }

  void removeStudent(String student) {
    state = state.copyWith(
        hasChanges: true,
        class_: state.class_.copyWith(
            students: state.class_.students
                .where((s) => s.name != student)
                .toList()));
  }

  Future<bool> updateClass() async {
    try {
      state = state.copyWith(error: '', isLoading: true);
      await _repo.updateClass(state.class_);
      state = state.copyWith(isLoading: false, hasChanges: false);
      ref.invalidate(classListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: '');
  }
}
