import 'package:class_database/data/models/class.dart';
import 'package:class_database/data/services/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'class_list_vm.g.dart';

@riverpod
Stream<List<Class>> _fetchClasses(Ref ref) {
  final db = ref.watch(databaseProvider).value!;
  return db.collection('classes', Class.fromJson);
}

@riverpod
class ClassListVm extends _$ClassListVm {
  late Database _db;

  @override
  AsyncValue<List<Class>> build() {
    debugPrint("Building ClassListVm");
    final classes = ref.watch(_fetchClassesProvider);
    _db = ref.watch(databaseProvider).value!;
    return classes;
  }

  Future<Class> addClass(Class class_) async {
    try {
    _db.insert('classes', class_.toJson());
    debugPrint("AFTER INSERT");
    // class_.id = doc.id;
    }catch(e) {
      debugPrint("There was an error");
    }
    return class_;
  }
}