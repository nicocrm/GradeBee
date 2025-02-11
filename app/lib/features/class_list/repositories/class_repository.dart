import 'package:get_it/get_it.dart';

import '../../../shared/data/database.dart';
import '../../../shared/data/storage_service.dart';
import '../../../shared/logger.dart';
import '../models/class.model.dart';
import '../models/note.model.dart';

class ClassRepository {
  final DatabaseService _db;
  final StorageService _storageService;

  ClassRepository([DatabaseService? database, StorageService? storageService])
      : _db = database ?? GetIt.instance<DatabaseService>(),
        _storageService = storageService ?? GetIt.instance<StorageService>();

  Future<List<Class>> listClasses() async {
    try {
      return await _db.list('classes', Class.fromJson);
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

  Future<Class> updateClass(Class class_) async {
    try {
      final newNotes = <Note>[];
      for (var pendingNote in class_.pendingNotes) {
        final fileId = await _storageService.upload(
            pendingNote.recordingPath, "voice_note.m4a");
        newNotes.add(Note(
          voice: fileId,
          when: pendingNote.when,
          isSplit: false,
          id: fileId,
        ));
      }
      class_ = class_
          .copyWith(notes: [...class_.notes, ...newNotes], pendingNotes: []);
      await _db.update('classes', class_.toJson(), class_.id!);
      return class_;
    } catch (e, s) {
      AppLogger.error('Error updating class', e, s);
      rethrow;
    }
  }

  /// Add pending notes to the class using the local storage service
  Future<Class> getClassWithNotes(Class class_) async {
    // currently we just don't do anything, the notes are uploaded when the class is updated
    return class_;
  }
}
