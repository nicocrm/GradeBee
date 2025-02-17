import '../../../data/services/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/class.model.dart';
import 'class_state_mixin.dart';

part 'class_add_vm.g.dart';

@riverpod
class ClassAddVm extends _$ClassAddVm with ClassStateMixin {
  late final Database _db;

  @override
  Class build() {
    _db = ref.watch(databaseProvider).requireValue;
    return Class(course: '', dayOfWeek: null, room: '');
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

  Future<Class?> addClass() async {
    final id = await _db.insert('classes', state.toJson());
    return state.copyWith(id: id);
  }
}
