import '../models/class.model.dart';
import '../repositories/class_repository.dart';

class ClassListVM {
  final ClassRepository _repository;

  ClassListVM([ClassRepository? repository])
      : _repository = repository ?? ClassRepository();

  Future<List<Class>> listClasses() {
    return _repository.listClasses();
  }
}
