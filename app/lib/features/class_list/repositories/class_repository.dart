import '../../../shared/data/database.dart';

import '../../../shared/logger.dart';
import '../models/class.model.dart';

class ClassRepository {
  final Database _db;

  ClassRepository([Database? database]) : _db = database ?? Database();

  Future<List<Class>> listClasses() async {
    try {
      return await _db.list('classes', Class.fromJson);
    } catch (e) {
      AppLogger.error('Error listing classes');
      rethrow;
    }
  }

  Future<Class> updateClass(Class class_) async {
    try {
      await _db.update('classes', class_.toJson(), class_.id!);
      return class_;
    } catch (e) {
      AppLogger.error('Error updating class');
      rethrow;
    }
  }
}
