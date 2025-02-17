import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    @Default('') String error,
  }) = _ClassDetailsState;
}

@riverpod
class ClassDetailsVm extends _$ClassDetailsVm with ClassStateMixin<ClassDetailsState> {
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
    state = state.copyWith(class_: state.class_.copyWith(course: course));
  }

  @override
  void setDayOfWeek(String dayOfWeek) {
    state = state.copyWith(class_: state.class_.copyWith(dayOfWeek: dayOfWeek));
  }

  @override
  void setRoom(String room) {
    state = state.copyWith(class_: state.class_.copyWith(room: room));
  }

  Future<bool> updateClass() async {
    try {
      state = state.copyWith(error: '', isLoading: true);
      await _repo.updateClass(state.class_);
      state = state.copyWith(isLoading: false);
      ref.invalidate(classListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }
}
