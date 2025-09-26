import 'package:appwrite/appwrite.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

import '../../../shared/data/database.dart';
import '../../../shared/data/sync_service.dart';
import '../../../shared/logger.dart';
import '../models/class.model.dart';
import '../models/note.model.dart';
import '../models/pending_note.model.dart';

class ClassRepository {
  final DatabaseService _db;
  final SyncService _syncService;

  ClassRepository([
    DatabaseService? database,
    SyncService? syncService,
  ])  : _db = database ?? GetIt.instance<DatabaseService>(),
        _syncService = syncService ?? GetIt.instance<SyncService>();

  Future<List<Class>> listClasses() async {
    try {
      return await _db.list('classes', Class.fromJson, queries: [
        Query.equal('school_year', '2025-2026'),
        Query.select(['*', 'students.*', 'notes.*'])
      ]);
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

  Future<void> savePendingNotesLocally(Class class_) async {
    try {
      final pendingNotes = class_.notes.whereType<PendingNote>().toList();
      if (pendingNotes.isEmpty) return;

      // Convert pending notes to JSON format
      final notesJson = jsonEncode({
        'classId': class_.id,
        'pendingNotes': pendingNotes
            .map((note) => {
                  'recordingPath': note.recordingPath,
                  'when': note.when.toIso8601String(),
                })
            .toList(),
      });

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_notes_${class_.id}', notesJson);
    } catch (e, s) {
      AppLogger.error('Error saving pending notes locally', e, s);
    }
  }

  Future<Class> retrieveLocalPendingNotes(Class class_) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString('pending_notes_${class_.id}');
      if (notesJson == null) return class_;

      final notesMap = jsonDecode(notesJson) as Map<String, dynamic>;
      final pendingNotesList = (notesMap['pendingNotes'] as List)
          .map((noteMap) => PendingNote(
                when: DateTime.parse(noteMap['when']),
                recordingPath: noteMap['recordingPath'],
              ))
          .toList();

      return class_.copyWith(
        notes: [
          ...class_.notes.where((n) => n is! PendingNote),
          ...pendingNotesList
        ],
      );
    } catch (e, s) {
      AppLogger.error('Error retrieving pending notes', e, s);
      return class_;
    }
  }

  /// Cleans up synced pending notes by:
  /// 1. Removing them from SharedPreferences
  /// 2. Deleting the associated recording files
  Future<void> cleanupSyncedPendingNotes(
      Class class_, List<Note> syncedNotes) async {
    try {
      // Get the current pending notes from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString('pending_notes_${class_.id}');
      if (notesJson == null) return;

      final notesMap = jsonDecode(notesJson) as Map<String, dynamic>;
      final pendingNotes = (notesMap['pendingNotes'] as List)
          .map((noteMap) => {
                'recordingPath': noteMap['recordingPath'] as String,
                'when': noteMap['when'] as String,
              })
          .toList();

      // Filter out the synced notes (keeping only unsyncedNotes)
      final syncedFilePaths = syncedNotes
          .whereType<PendingNote>()
          .map((note) => note.recordingPath)
          .toList();

      final unsyncedNotes = pendingNotes
          .where(
              (noteMap) => !syncedFilePaths.contains(noteMap['recordingPath']))
          .toList();

      // Delete synced recording files
      for (final path in syncedFilePaths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          AppLogger.info('Deleted synced recording file: $path');
        }
      }

      if (unsyncedNotes.isEmpty) {
        // If all notes are synced, remove the entire entry
        await prefs.remove('pending_notes_${class_.id}');
      } else {
        // Otherwise, update SharedPreferences with remaining unsynced notes
        final updatedJson = jsonEncode({
          'classId': class_.id,
          'pendingNotes': unsyncedNotes,
        });
        await prefs.setString('pending_notes_${class_.id}', updatedJson);
      }
    } catch (e, s) {
      AppLogger.error('Error cleaning up synced pending notes', e, s);
    }
  }

  Future<Class> updateClass(Class class_) async {
    try {
      final pendingNotes = class_.notes.whereType<PendingNote>().toList();

      // First save pending notes locally in case sync fails
      await savePendingNotesLocally(class_);

      // Enqueue each pending note for background sync
      for (var pendingNote in pendingNotes) {
        _syncService.enqueuePendingNote(pendingNote, class_.id!);
      }

      // Update the class in the database (does not include notes)
      await _db.update('classes', class_.toJson(), class_.id!);
      return class_;
    } catch (e, s) {
      AppLogger.error('Error updating class', e, s);
      rethrow;
    }
  }

  /// Add pending notes to the class using the local storage service
  Future<Class> getClassWithNotes(Class class_) async {
    // Load any pending notes from local storage
    return await retrieveLocalPendingNotes(class_);
  }
}
