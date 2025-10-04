import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/class_list/models/note.model.dart';

/// Event types for note synchronization lifecycle
enum NoteSyncEventType {
  /// Note sync has started
  syncStarted,
  /// Note sync has completed successfully
  syncCompleted,
  /// Note sync has failed
  syncFailed,
  /// Note has been processed on server and parsed text is available
  noteProcessed,
}

/// Event data for note synchronization
class NoteSyncEvent {
  final NoteSyncEventType type;
  final Note note;
  final String? error;

  NoteSyncEvent({
    required this.type,
    required this.note,
    this.error,
  });

  @override
  String toString() {
    return 'NoteSyncEvent(type: $type, noteId: ${note.id}, error: $error)';
  }
}

/// Global event bus for note synchronization events
/// This allows decoupled communication between sync service and UI components
class NoteSyncEventBus {
  final StreamController<NoteSyncEvent> _eventController = 
      StreamController<NoteSyncEvent>.broadcast();

  /// Stream of note sync events
  Stream<NoteSyncEvent> get events => _eventController.stream;

  void emit(NoteSyncEvent event) {
    if (kDebugMode) {
      print('NoteSyncEventBus: Emitting event - $event');
    }
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
  }
}
