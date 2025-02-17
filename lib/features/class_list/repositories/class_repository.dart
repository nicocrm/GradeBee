import '../../../data/services/database.dart';
import '../models/class.model.dart';

class ClassRepository {
  final Database _db;

  ClassRepository([Database? database]) : _db = database ?? Database();

  Future<List<Class>> listClasses() {
    return _db.list('classes', Class.fromJson);
  }

  Future<void> updateClass(Class class_) {
    return _db.update('classes', class_.toJson(), class_.id!);
  }
}
