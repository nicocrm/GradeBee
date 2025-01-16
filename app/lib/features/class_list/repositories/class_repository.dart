import '../../../data/services/database.dart';
import 'package:gradebee_models/common.dart';

class ClassRepository {
  final Database _db;

  ClassRepository([Database? database]) : _db = database ?? Database();

  Future<List<Class>> listClasses() {
    return _db.list('classes', Class.fromJson);
  }

  Future<Class> updateClass(Class class_) async {
    await _db.update('classes', class_.toJson(), class_.id!);
    return class_;
  }
}
