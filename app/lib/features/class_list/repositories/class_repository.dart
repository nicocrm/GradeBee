import 'package:get_it/get_it.dart';

import '../../../shared/data/database.dart';
import '../../../shared/data/storage_service.dart';
import '../../../shared/logger.dart';
import '../models/class.model.dart';
import '../models/note.model.dart';

class ClassRepository {
  final Database _db;
  final StorageService _storageService;

  ClassRepository([Database? database, StorageService? storageService])
      : _db = database ?? GetIt.instance<Database>(),
        _storageService = storageService ?? GetIt.instance<StorageService>();

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
      for (var pendingNote in class_.pendingNotes) {
        final fileId = await _storageService.upload(pendingNote.recordingPath);
        class_.notes.add(Note(
          voice: fileId,
          when: pendingNote.when,
          isSplit: false,
          id: fileId,
        ));
      }
      class_.pendingNotes.clear();
      await _db.update('classes', class_.toJson(), class_.id!);
      return class_;
    } catch (e) {
      AppLogger.error('Error updating class');
      rethrow;
    }
  }

  /// Add pending notes to the class using the local storage service
  Future<Class> getClassWithNotes(Class class_) async {
    // currently we just don't do anything, the notes are uploaded when the class is updated
    return class_;
  }
}
