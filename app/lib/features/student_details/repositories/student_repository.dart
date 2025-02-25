import 'package:get_it/get_it.dart';

import '../../../shared/data/database.dart';
import '../../../shared/logger.dart';
import '../models/report_card.model.dart';
import '../models/student.model.dart';

class StudentRepository {
  final DatabaseService _db;

  StudentRepository() : _db = GetIt.instance<DatabaseService>();

  Future<Student> getStudent(String id) async {
    try {
      return await _db.get('students', Student.fromJson, id);
    } catch (e) {
      AppLogger.error('Error getting student');
      rethrow;
    }
  }

  Future<void> updateReportCard(ReportCard reportCard) async {
    await _db.update('report_cards', reportCard.toJson(), reportCard.id);
  }
}
