import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/services/database.dart';
import '../models/class.model.dart';

part 'class_repository.g.dart';

@riverpod
class ClassRepository extends _$ClassRepository {
  late final Database _db;

  @override
  ClassRepository build() {
    _db = ref.watch(databaseProvider).requireValue;
    return this;
  }

  Future<List<Class>> listClasses() {
    return _db.list('classes', Class.fromJson);
  }

  Future<void> updateClass(Class class_) {
    return _db.update('classes', class_.toJson(), {'id': class_.id});
  }
}

@riverpod
Future<List<Class>> classList(Ref ref) {
  return ref.watch(classRepositoryProvider).listClasses();
}