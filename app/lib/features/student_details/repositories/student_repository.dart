import 'package:appwrite/appwrite.dart';

import '../../../shared/data/database.dart';
import '../../../shared/logger.dart';
import '../models/student.model.dart';

class StudentRepository {
  final DatabaseService _db;

  StudentRepository(this._db);

  Future<Student> getStudent(String id) async {
    try {
      return await _db.get(
        'students',
        Student.fromJson,
        id,
        queries: [
          Query.select([
            '*',
            'notes.*',
            'report_cards.*',
            'report_cards.template.*',
            'report_cards.sections.*',
          ]),
        ],
      );
    } catch (e) {
      AppLogger.error('Error getting student');
      rethrow;
    }
  }

  Future<Student> updateStudent(Student student) async {
    await _db.update('students', student.toJson(), student.id);
    return getStudent(student.id);
  }
}
