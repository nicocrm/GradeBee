import 'dart:isolate';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../../features/class_list/models/pending_note.model.dart';
import '../logger.dart';
import './database.dart';
import './storage_service.dart';

/// Service responsible for background synchronization of pending notes
class SyncService with WidgetsBindingObserver {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  
  Isolate? _isolate;
  SendPort? _sendPort;
  final Set<String> _processingNotes = <String>{}; // Track notes currently being processed

  SyncService._() {
    initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initialize() async {
    // there is a very slight race condition here because we don't await the initialize()
    // in normal usage it won't happen, by the time the user is recording notes, initialize will be long done
    await _startSyncIsolate();
    await _checkForPendingNotes();
  }


  Future<void> _checkForPendingNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final pendingNoteKeys = allKeys.where((key) => key.startsWith('pending_notes_')).toList();

      for (final key in pendingNoteKeys) {
        final notesJson = prefs.getString(key);
        if (notesJson == null) continue;

        final notesMap = jsonDecode(notesJson) as Map<String, dynamic>;
        final classId = notesMap['classId'];
        final pendingNotes = (notesMap['pendingNotes'] as List);

        AppLogger.info('Found ${pendingNotes.length} pending notes for class $classId');

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
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((noteData) async {
      final noteId = noteData['noteId'];
      try {
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
            AppLogger.info('Removed empty pending notes entry for class ${noteData['classId']}');
          } else {
            await prefs.setString(key, jsonEncode({
              'classId': noteData['classId'],
              'pendingNotes': remainingNotes,
            }));
            AppLogger.info('Updated pending notes, ${remainingNotes.length} notes remaining for class ${noteData['classId']}');
          }
        }
      } catch (e, s) {
        AppLogger.error('Failed to sync note: ${noteData['recordingPath']}', e, s);
      } finally {
        // Send completion message back to main isolate
        sendPort.send({
          'type': 'completed',
          'noteId': noteId,
        });
      }
    });
  }

  void enqueuePendingNote(PendingNote note, String classId) {
    if (_sendPort == null) {
      // super unlikely to happen, but just in case - and in that case we'll just send it next time the app is started
      AppLogger.warning('SyncService not ready yet, skipping note');
      return;
    }
    final noteId = _generateNoteId(note.recordingPath, note.when.toIso8601String());
    
    if (_processingNotes.contains(noteId)) {
      AppLogger.info('Note already being processed, skipping: ${note.recordingPath}');
      return;
    }
    
    AppLogger.info('Enqueueing new note for sync: ${note.recordingPath}');
    _processingNotes.add(noteId);
    _sendPort!.send({
      'recordingPath': note.recordingPath,
      'when': note.when.toIso8601String(),
      'classId': classId,
      'noteId': noteId,
    });
  }

  /// Generates a unique ID for a note based on recording path and timestamp
  String _generateNoteId(String recordingPath, String when) {
    return '${recordingPath}_$when';
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isolate?.kill();
  }
} 