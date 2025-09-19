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
  
  final _syncQueue = StreamController<Map<String, dynamic>>();
  Isolate? _isolate;
  SendPort? _sendPort;

  SyncService._() {
    _startSyncIsolate();
    WidgetsBinding.instance.addObserver(this);
    _checkForPendingNotes();
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
          _syncQueue.add({
            'recordingPath': noteData['recordingPath'],
            'when': noteData['when'],
            'classId': classId,
          });
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

    _syncQueue.stream.listen((noteData) {
      _sendPort?.send(noteData);
    });
  }

  static void _syncWorker(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((noteData) async {
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
      }
    });
  }

  void enqueuePendingNote(PendingNote note, String classId) {
    AppLogger.info('Enqueueing new note for sync: ${note.recordingPath}');
    _syncQueue.add({
      'recordingPath': note.recordingPath,
      'when': note.when.toIso8601String(),
      'classId': classId,
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isolate?.kill();
    _syncQueue.close();
  }
} 