import 'dart:isolate';
import 'dart:async';
import 'package:flutter/services.dart';
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
  final Set<String> _processingNotes = <String>{}; // Track notes currently being processed

  SyncService(Map<String, String> environment) {
    initialize(environment);
    WidgetsBinding.instance.addObserver(this);
  }

  static SyncService createInstance(Map<String, String> environment) {
    if (kIsWeb) {
      return SyncServiceCompute(environment);
    } else {
      return SyncServiceIsolate(environment);
    }
  }

  Future<void> initialize(Map<String, String> environment) async {
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

  SyncServiceIsolate(super.environment);

  @override
  Future<void> initialize(Map<String, String> environment) async {
    await _startSyncIsolate(environment);
    await super.initialize(environment);
  }

  Future<void> _startSyncIsolate(Map<String, String> environment) async {
    final receivePort = ReceivePort();
    final token = RootIsolateToken.instance!;
    _isolate = await Isolate.spawn(_syncWorker, _IsolateData(token: token, answerPort: receivePort.sendPort, environment: environment));
    
    // Listen to all messages from the worker
    receivePort.listen((message) {
      if (message is SendPort) {
        // First message is the worker's send port
        _sendPort = message;
        AppLogger.info('Sync isolate initialized');
      } else if (message is Map && message['type'] == 'completed') {
        // Completion messages
        final noteId = message['noteId'];
        _processingNotes.remove(noteId);
        AppLogger.info('Note processing completed: $noteId');
      }
    });
  }


  static void _syncWorker(_IsolateData data) {
    AppLogger.info('Sync worker started');
    // Initialize services in this isolate's GetIt instance
    BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
    
    final receivePort = ReceivePort();
    final sendPort = data.answerPort;
    sendPort.send(receivePort.sendPort);

    receivePort.listen((noteData) async {
      AppInitializer.initializeServices(data.environment);

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

class _IsolateData {
  final RootIsolateToken token;
  final SendPort answerPort;
  final Map<String, String> environment;

  _IsolateData({
    required this.token,
    required this.answerPort,
    required this.environment,
  });
}

/// SyncService implementation using Compute for web platforms
/// This assumes that the environment is already initialized and available within the compute worker
/// (on the web it should not be a problem)
class SyncServiceCompute extends SyncService {
  SyncServiceCompute(super.environment);

  static Future<void> syncNoteCompute(Map<String, dynamic> noteData) async {
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