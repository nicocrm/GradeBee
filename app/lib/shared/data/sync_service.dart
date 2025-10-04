import 'dart:async';
import 'dart:io';
import '../../features/class_list/models/note.model.dart';
import '../../features/class_list/models/pending_note.model.dart';
import '../../features/class_list/repositories/class_repository.dart';
import '../logger.dart';
import './storage_service.dart';
import 'local_storage.dart';
import 'note_sync_event_bus.dart';

class NoteSyncWorker {
  final StorageService storageService;
  final ClassRepository classRepository;

  NoteSyncWorker(this.storageService, this.classRepository);
}

class SyncService {
  final Set<String> _processingNotes =
      <String>{}; // Track notes currently being processed
  final NoteSyncEventBus noteEventBus;
  final LocalStorage<PendingNote> _localStorage;
  final StorageService _storageService;
  final ClassRepository classRepository;

  SyncService(
    this.noteEventBus,
    this._localStorage,
    this._storageService,
    this.classRepository,
  );

  Future<void> checkForPendingNotes() async {
    try {
      final pendingNotes = await _localStorage.retrieveAllLocalInstances();
      for (final classId in pendingNotes.keys) {
        for (final pendingNote in pendingNotes[classId]!) {
          unawaited(enqueuePendingNote(pendingNote, classId));
        }
      }
    } catch (e, s) {
      AppLogger.error('Error checking for pending notes', e, s);
    }
  }

  Future<void> enqueuePendingNote(PendingNote noteData, String classId) async {
    noteEventBus.emit(NoteSyncEvent(type: NoteSyncEventType.syncStarted, note: noteData));
    if (!_processingNotes.add(noteData.id)) {
      AppLogger.info(
        'Note already being processed, skipping: ${noteData.recordingPath}',
      );
      return;
    }

    AppLogger.info('Enqueueing new note for sync: ${noteData.recordingPath}');
    await processNote(noteData, classId);
  }

  Future<void> processNote(PendingNote noteData, String classId) async {
    try {
      final result = await _uploadNote(noteData, classId);
      await _localStorage.removeLocalInstance(classId, noteData.id);
      AppLogger.info('Note processing completed: ${noteData.id}');
      _handleSyncResult(result);
    } catch (e, s) {
      AppLogger.error('Error processing note', e, s);
      // don't clean up, so we can attempt it again
      _handleSyncResult(
        NoteSyncEvent(type: NoteSyncEventType.syncFailed, note: noteData, error: e.toString()),
      );
    }
  }

  Future<NoteSyncEvent> _uploadNote(PendingNote noteData, String classId) async {
    // Verify file exists before attempting upload
    final file = File(noteData.recordingPath);
    if (!await file.exists()) {
      AppLogger.error('Recording file not found: ${noteData.recordingPath}');
      return NoteSyncEvent(
        note: noteData,
        type: NoteSyncEventType.syncFailed,
        error: 'Recording file not found',
      );
    }
    final fileId = await _storageService.upload(
      noteData.recordingPath,
      "voice_note.m4a",
    );
    final syncedNote = Note.fromJson({...noteData.toJson(), 'voice': fileId});
    await classRepository.addSavedNote(classId, syncedNote);
    try {
      await file.delete();
    } catch (e, s) {
      AppLogger.error('Error deleting note file', e, s);
    }

    AppLogger.info('Successfully synced note: ${noteData.recordingPath}');
    return NoteSyncEvent(
      note: syncedNote,
      type: NoteSyncEventType.syncCompleted,
    );
  }

  void _handleSyncResult(NoteSyncEvent message) {
    _processingNotes.remove(message.note.id);
    noteEventBus.emit(message);
  }
}
