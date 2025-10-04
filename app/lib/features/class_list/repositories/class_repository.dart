import 'package:appwrite/appwrite.dart';
import 'package:get_it/get_it.dart';

import '../../../shared/data/database.dart';
import '../../../shared/data/local_storage.dart';
import '../../../shared/logger.dart';
import '../models/class.model.dart';
import '../models/note.model.dart';
import '../models/pending_note.model.dart';

class ClassRepository {
  final DatabaseService _db;
  final LocalStorage<PendingNote> _localStorage;

  ClassRepository([
    DatabaseService? db,
    LocalStorage<PendingNote>? localStorage,
  ]) : _db = db ?? GetIt.instance<DatabaseService>(),
       _localStorage =
           localStorage ?? GetIt.instance<LocalStorage<PendingNote>>();

  Future<List<Class>> listClasses() async {
    try {
      return await _db.list(
        'classes',
        Class.fromJson,
        queries: [
          // hard coded for now...
          Query.equal('school_year', '2025-2026'),
          Query.select(['*', 'students.*', 'notes.*']),
        ],
      );
    } catch (e) {
      AppLogger.error('Error listing classes');
      rethrow;
    }
  }

  Future<Class> addClass(Class class_) async {
    try {
      final id = await _db.insert('classes', class_.toJson());
      return class_.copyWith(id: id);
    } catch (e) {
      AppLogger.error('Error adding class');
      rethrow;
    }
  }

  Future<void> addSavedNote(String classId, Note note) async {
    try {
      final json = note.toJson();
      json['class'] = classId;
      await _db.insert('notes', json);
    } catch (e) {
      AppLogger.error('Error adding saved note');
      rethrow;
    }
  }

  Future<Class> retrieveLocalPendingNotes(Class class_) async {
    try {
      final pendingNotes = await _localStorage.retrieveLocalInstances(
        class_.id!,
      );
      return class_.copyWith(pendingNotes: pendingNotes);
    } catch (e, s) {
      AppLogger.error('Error retrieving pending notes', e, s);
      return class_;
    }
  }

  Future<Class> updateClass(Class class_) async {
    try {
      await _localStorage.saveLocalInstances(class_.id!, class_.pendingNotes);
      await _db.update('classes', class_.toJson(), class_.id!);
      return class_;
    } catch (e, s) {
      AppLogger.error('Error updating class', e, s);
      rethrow;
    }
  }

  Future<Class> getClassDetails(Class class_) async {
    // Load any pending notes from local storage
    return await retrieveLocalPendingNotes(class_);
  }
}
