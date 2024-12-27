import 'package:class_database/data/services/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/class.model.dart';

part 'class_add_vm.freezed.dart';
part 'class_add_vm.g.dart';

@freezed
class ClassAddState with _$ClassAddState {
  factory ClassAddState({
    required bool isLoading,
    required String error,
  }) = _ClassAddState;
}

@riverpod
class ClassAddVm extends _$ClassAddVm {
  late final Database _db;

  @override
  ClassAddState build() {
    _db = ref.watch(databaseProvider).requireValue;
    return ClassAddState(isLoading: false, error: '');
  }

  Future<Class?> addClass(Class class_) async {
    try {
      state = state.copyWith(error: '', isLoading: true);
      final id = await _db.insert('classes', class_.toJson());
      state = state.copyWith(isLoading: false);
      return class_.copyWith(id: id);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }
}
