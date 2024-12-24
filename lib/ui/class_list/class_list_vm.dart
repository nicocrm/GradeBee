import 'package:class_database/data/models/class.dart';
import 'package:class_database/data/services/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'class_list_vm.g.dart';

@riverpod
Stream<List<Class>> fetchClasses(Ref ref) {
  final db = ref.watch(databaseProvider).value!;
  return db.firestore.collection('classes').snapshots().map((snapshot) {
    return snapshot.docs
        .map((doc) => Class.fromJson(doc.data()))
        .toList();
  });
}
