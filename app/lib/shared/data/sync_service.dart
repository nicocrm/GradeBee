import 'dart:isolate';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../../features/class_list/models/pending_note.model.dart';
import '../logger.dart';
import './database.dart';
import './storage_service.dart';
import './app_initializer.dart';

/// Abstract service responsible for background synchronization of pending notes
abstract class SyncService with WidgetsBindingObserver {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= _createInstance();

  final Set<String> _processingNotes = <String>{}; // Track notes currently being processed

  SyncService() {
    initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  static SyncService _createInstance() {
    if (kIsWeb) {
      return SyncServiceCompute();
    } else {
      return SyncServiceIsolate();
    }
  }

  Future<void> initialize() async {
    await _checkForPendingNotes();
  }

  Future<void> _checkForPendingNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final pendingNoteKeys =
          allKeys.where((key) => key.startsWith('pending_notes_')).toList();

      for (final key in pendingNoteKeys) {
        final notesJson = prefs.getString(key);
        if (notesJson == null) continue;

        final notesMap = jsonDecode(notesJson) as Map<String, dynamic>;
        final classId = notesMap['classId'];
        final pendingNotes = (notesMap['pendingNotes'] as List);

        AppLogger.info(
            'Found ${pendingNotes.length} pending notes for class $classId');

        for (final noteData in pendingNotes) {
          final pendingNote = PendingNote(
            when: DateTime.parse(noteData['when']),
            recordingPath: noteData['recordingPath'],
          );
          enqueuePendingNote(pendingNote, classId);
        }
      }
    } catch (e, s) {
      AppLogger.error('Error checking for pending notes', e, s);
    }
  }

  static Future<void> syncNoteCompute(Map<String, dynamic> noteData) async {
    final storageService = GetIt.instance<StorageService>();
    final dbService = GetIt.instance<DatabaseService>();

    AppLogger.info('Syncing note: ${noteData['recordingPath']}');

    // Verify file exists before attempting upload
    final file = File(noteData['recordingPath']);
    if (!await file.exists()) {
      AppLogger.error('Recording file not found: ${noteData['recordingPath']}');
      return;
    }

    final fileId = await storageService.upload(
      noteData['recordingPath'],
      "voice_note.m4a",
    );

    await dbService.insert('notes', {
      'voice': fileId,
      'when': noteData['when'],
      'class': noteData['classId'],
    });

    AppLogger.info('Successfully synced note: ${noteData['recordingPath']}');

    // Clean up the synced note from local storage
    final prefs = await SharedPreferences.getInstance();
    final key = 'pending_notes_${noteData['classId']}';
    final notesJson = prefs.getString(key);

    if (notesJson != null) {
      final notesMap = jsonDecode(notesJson);
      final remainingNotes = (notesMap['pendingNotes'] as List)
          .where((note) => note['recordingPath'] != noteData['recordingPath'])
          .toList();

      if (remainingNotes.isEmpty) {
        await prefs.remove(key);
        AppLogger.info(
            'Removed empty pending notes entry for class ${noteData['classId']}');
      } else {
        await prefs.setString(
            key,
            jsonEncode({
              'classId': noteData['classId'],
              'pendingNotes': remainingNotes,
            }));
        AppLogger.info(
            'Updated pending notes, ${remainingNotes.length} notes remaining for class ${noteData['classId']}');
      }
    }
  }

  void enqueuePendingNote(PendingNote note, String classId) {
    final noteId =
        _generateNoteId(note.recordingPath, note.when.toIso8601String());

    if (_processingNotes.contains(noteId)) {
      AppLogger.info(
          'Note already being processed, skipping: ${note.recordingPath}');
      return;
    }

    AppLogger.info('Enqueueing new note for sync: ${note.recordingPath}');
    _processingNotes.add(noteId);
    final noteData = {
      'recordingPath': note.recordingPath,
      'when': note.when.toIso8601String(),
      'classId': classId,
      'noteId': noteId,
    };
    
    processNote(noteData);
  }

  /// Abstract method to process a note - implemented by concrete classes
  void processNote(Map<String, dynamic> noteData);

  /// Generates a unique ID for a note based on recording path and timestamp
  String _generateNoteId(String recordingPath, String when) {
    return '${recordingPath}_$when';
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  // Public method to access processing notes for testing
  void removeProcessingNote(String noteId) {
    _processingNotes.remove(noteId);
  }
}

/// SyncService implementation using Isolate for non-web platforms
class SyncServiceIsolate extends SyncService {
  Isolate? _isolate;
  SendPort? _sendPort;

  @override
  Future<void> initialize() async {
    await _startSyncIsolate();
    await super.initialize();
  }

  Future<void> _startSyncIsolate() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_syncWorker, receivePort.sendPort);
    _sendPort = await receivePort.first;

    // Listen for completion messages from worker
    receivePort.listen((message) {
      if (message is Map && message['type'] == 'completed') {
        final noteId = message['noteId'];
        _processingNotes.remove(noteId);
        AppLogger.info('Note processing completed: $noteId');
      }
    });
  }

  static void _syncWorker(SendPort sendPort) {
    // Initialize services in this isolate's GetIt instance
    AppInitializer.initializeServices();
    
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((noteData) async {
      final noteId = noteData['noteId'];
      try {
        await SyncService.syncNoteCompute(noteData);
      } catch (e, s) {
        AppLogger.error(
            'Failed to sync note: ${noteData['recordingPath']}', e, s);
      } finally {
        // Send completion message back to main isolate
        sendPort.send({
          'type': 'completed',
          'noteId': noteId,
        });
      }
    });
  }

  @override
  void processNote(Map<String, dynamic> noteData) {
    if (_sendPort == null) {
      // This should not happen in normal use - isolate should be initialized before any notes are processed
      AppLogger.error('SyncServiceIsolate: _sendPort is null, cannot process note: ${noteData['recordingPath']}');
      _processingNotes.remove(noteData['noteId']);
      return;
    }
    
    _sendPort!.send(noteData);
  }

  @override
  void dispose() {
    super.dispose();
    _isolate?.kill();
  }
}

/// SyncService implementation using Compute for web platforms
class SyncServiceCompute extends SyncService {
  static Future<void> syncNoteCompute(Map<String, dynamic> noteData) async {
    AppInitializer.initializeServices();
    await SyncService.syncNoteCompute(noteData);
  }

  @override
  void processNote(Map<String, dynamic> noteData) {
    compute(SyncServiceCompute.syncNoteCompute, noteData).then((_) {
      _processingNotes.remove(noteData['noteId']);
      AppLogger.info('Note processing completed: ${noteData['noteId']}');
    }).catchError((e, s) {
      _processingNotes.remove(noteData['noteId']);
      AppLogger.error('Failed to sync note: ${noteData['recordingPath']}', e, s);
    });
  }
}