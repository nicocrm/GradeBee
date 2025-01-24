import '../models/student.model.dart';
import '../repositories/student_repository.dart';

class StudentDetailsVM {
  final String studentId;
  final StudentRepository _repository;

  StudentDetailsVM(this.studentId, [StudentRepository? repository])
      : _repository = repository ?? StudentRepository();

  Future<Student> getStudent() async {
    return _repository.getStudent(studentId);
  }
}
