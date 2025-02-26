import '../../../shared/data/database.dart';
import '../../../shared/logger.dart';
import '../models/student.model.dart';

class StudentRepository {
  final DatabaseService _db;

  StudentRepository(this._db);

  Future<Student> getStudent(String id) async {
    try {
      return await _db.get('students', Student.fromJson, id);
    } catch (e) {
      AppLogger.error('Error getting student');
      rethrow;
    }
  }

  Future<void> updateStudent(Student student) async {
    await _db.update('students', student.toJson(), student.id);
  }
}
