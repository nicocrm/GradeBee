import '../../../data/services/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/class.model.dart';
import 'class_state_mixin.dart';

part 'class_add_vm.freezed.dart';
part 'class_add_vm.g.dart';

@freezed
class ClassAddState extends ClassState with _$ClassAddState {
  factory ClassAddState({
    required bool isLoading,
    required String error,
    required Class class_,
  }) = _ClassAddState;
}

@riverpod
class ClassAddVm extends _$ClassAddVm with ClassStateMixin<ClassAddState> {
  late final Database _db;

  @override
  ClassAddState build() {
    _db = ref.watch(databaseProvider).requireValue;
    return ClassAddState(
        isLoading: false,
        error: '',
        class_: Class(course: '', dayOfWeek: null, room: ''));
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

  void clearError() {
    state = state.copyWith(error: '');
  }

  Future<Class?> addClass() async {
    try {
      state = state.copyWith(error: '', isLoading: true);
      final id = await _db.insert('classes', state.class_.toJson());
      state = state.copyWith(isLoading: false);
      return state.class_.copyWith(id: id);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }
}
