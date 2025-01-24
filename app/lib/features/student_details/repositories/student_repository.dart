import '../../../shared/data/database.dart';
import '../../../shared/logger.dart';
import '../models/student.model.dart';

class StudentRepository {
  final Database _db;

  StudentRepository([Database? database]) : _db = database ?? Database();

  Future<Student> getStudent(String id) async {
    try {
      return await _db.get('students', Student.fromJson, id);
    } catch (e) {
      AppLogger.error('Error getting student');
      rethrow;
    }
  }
}
