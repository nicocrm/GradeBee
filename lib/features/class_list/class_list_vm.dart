import 'package:class_database/features/class_list/models/class.model.dart';
import 'package:class_database/data/services/database.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'class_list_vm.g.dart';

@riverpod
class ClassListVm extends _$ClassListVm {
  late Database _db;

  @override
  FutureOr<List<Class>> build() async {
    debugPrint("Building ClassListVm");
    _db = ref.watch(databaseProvider).requireValue;
    return _db.list('classes', Class.fromJson);
  }

  Future<Class> addClass(Class class_) async {
    try {
      final id = await _db.insert('classes', class_.toJson());
      debugPrint("AFTER INSERT");
      class_.id = id;
      ref.invalidateSelf();
    } catch (e) {
      debugPrint("There was an error");
    }
    return class_;
  }
}
