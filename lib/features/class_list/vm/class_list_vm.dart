import '../models/class.model.dart';
import '../../../data/services/database.dart';
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
}
