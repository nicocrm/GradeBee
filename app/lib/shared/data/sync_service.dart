import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'dart:io';
import '../../features/class_list/models/note.model.dart';
import '../../features/class_list/models/pending_note.model.dart';
import '../logger.dart';
import './database.dart';
import './storage_service.dart';
import './app_initializer.dart';
import 'local_storage.dart';
import 'note_sync_event_bus.dart';

class NoteSyncWorker {
  final StorageService storageService;
  final DatabaseService dbService;

  NoteSyncWorker(this.storageService, this.dbService);

  Future<NoteSyncEvent> uploadNote(PendingNote noteData) async {
    AppLogger.info('Syncing note: ${noteData.recordingPath}');

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

    final fileId = await storageService.upload(
      noteData.recordingPath,
      "voice_note.m4a",
    );
    final syncedNote = Note.fromJson({...noteData.toJson(), 'voice': fileId});

    await dbService.insert('notes', syncedNote.toJson());

    AppLogger.info('Successfully synced note: ${noteData.recordingPath}');
    return NoteSyncEvent(
      note: syncedNote,
      type: NoteSyncEventType.syncCompleted,
    );
  }
}

class SyncService {
  final Set<String> _processingNotes =
      <String>{}; // Track notes currently being processed
  final NoteSyncEventBus noteEventBus;
  final LocalStorage<PendingNote> localStorage;

  SyncService(this.noteEventBus, {LocalStorage<PendingNote>? localStorage})
    : localStorage =
          localStorage ?? LocalStorage('pending_notes', PendingNote.fromJson);

  Future<void> checkForPendingNotes() async {
    try {
      final pendingNotes = await localStorage.retrieveAllLocalInstances();
      for (final classId in pendingNotes.keys) {
        for (final pendingNote in pendingNotes[classId]!) {
          enqueuePendingNote(pendingNote, classId);
        }
      }
    } catch (e, s) {
      AppLogger.error('Error checking for pending notes', e, s);
    }
  }

  void enqueuePendingNote(PendingNote noteData, String classId) {
    if (_processingNotes.contains(noteData.id)) {
      AppLogger.info(
        'Note already being processed, skipping: ${noteData.recordingPath}',
      );
      return;
    }

    AppLogger.info('Enqueueing new note for sync: ${noteData.recordingPath}');
    _processingNotes.add(noteData.id);
    processNote(noteData, classId);
  }

  void processNote(PendingNote noteData, String classId) {
    final request = _NoteSyncRequest(
      token: RootIsolateToken.instance!,
      environment: dotenv.env,
      noteData: noteData,
    );
    unawaited(
      compute(SyncService._backgroundNoteSync, request)
          .then((result) async {
            AppLogger.info('Note processing completed: ${noteData.id}');
            await localStorage.removeLocalInstance(classId, noteData.id);
            _handleSyncResult(result);
          })
          .catchError((e, s) {
            AppLogger.error(
              'Failed to sync note: ${noteData.recordingPath}',
              e,
              s,
            );
            _handleSyncResult(
              NoteSyncEvent(type: NoteSyncEventType.syncFailed, note: noteData),
            );
          }),
    );
  }

  static Future<NoteSyncEvent> _backgroundNoteSync(
    _NoteSyncRequest request,
  ) async {
    // since this can run in isolate, we need to initialize the core services again
    AppInitializer.initializeServices(request.environment, coreOnly: true);
    final storageService = GetIt.instance<StorageService>();
    final dbService = GetIt.instance<DatabaseService>();
    final noteSyncWorker = NoteSyncWorker(storageService, dbService);
    return await noteSyncWorker.uploadNote(request.noteData);
  }

  void _handleSyncResult(NoteSyncEvent message) {
    _processingNotes.remove(message.note.id);
    noteEventBus.emit(message);
  }
}

class _NoteSyncRequest {
  final RootIsolateToken token;
  final Map<String, String> environment;
  final PendingNote noteData;

  _NoteSyncRequest({
    required this.token,
    required this.environment,
    required this.noteData,
  });
}
