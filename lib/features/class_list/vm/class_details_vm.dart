import 'package:class_database/features/class_list/models/class.model.dart';
import 'package:class_database/data/services/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'class_details_vm.freezed.dart';
part 'class_details_vm.g.dart';

@freezed
class ClassDetailsState with _$ClassDetailsState {
  factory ClassDetailsState({
    required Class class_,
    required bool isLoading,
    @Default('') String error,
  }) = _ClassDetailsState;
}

@riverpod
class ClassDetailsVm extends _$ClassDetailsVm {
  late Database _db;

  @override
  ClassDetailsState build(Class class_) {
    _db = ref.watch(databaseProvider).requireValue;
    return ClassDetailsState(
      class_: class_,
      isLoading: false,
    );
  }

  Future<bool> updateClass(Class class_) async {
    try {
      state = state.copyWith(error: '', isLoading: true);
      await _db.update('classes', class_.toJson(), {'id': class_.id});
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }
}
