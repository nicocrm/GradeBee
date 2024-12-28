import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'class_list_vm.dart';
import 'class_state_mixin.dart';

import '../models/class.model.dart';
import '../../../data/services/database.dart';
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
  late Database _db;

  @override
  ClassDetailsState build(Class originClass) {
    _db = ref.watch(databaseProvider).requireValue;
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
      await _db.update('classes', state.class_.toJson(), {'id': state.class_.id});
      state = state.copyWith(isLoading: false);
      ref.invalidate(classListVmProvider);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }
}
