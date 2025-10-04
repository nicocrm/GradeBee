import 'package:async/async.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../shared/data/database.dart';
import '../../../shared/data/note_sync_event_bus.dart';
import '../../../shared/data/sync_service.dart';
import '../../../shared/data/local_storage.dart';
import '../../../shared/ui/command.dart';
import '../models/class.model.dart';
import '../models/note.model.dart';
import '../models/pending_note.model.dart';
import '../models/student.model.dart';
import '../repositories/class_repository.dart';
import 'class_state_mixin.dart';

class ClassDetailsVM extends ChangeNotifier with ClassStateMixin {
  final ClassRepository _repository;
  final Class _initialClass;
  final NoteSyncEventBus _noteSyncEventBus;
  Class _class;
  late final Command0 updateClassCommand;
  late final StreamSubscription<NoteSyncEvent> _syncEventSubscription;
  final SyncService _syncService;

  ClassDetailsVM(
    Class initialClass, [
    ClassRepository? repository,
    NoteSyncEventBus? noteSyncEventBus,
    SyncService? syncService,
  ]) : _repository =
           repository ??
           ClassRepository(
             GetIt.instance<DatabaseService>(),
             GetIt.instance<LocalStorage<PendingNote>>(),
           ),
       _syncService = syncService ?? GetIt.instance<SyncService>(),
       _noteSyncEventBus =
           noteSyncEventBus ?? GetIt.instance<NoteSyncEventBus>(),
       _initialClass = initialClass,
       _class = initialClass {
    updateClassCommand = Command0(_updateClass);
    _syncEventSubscription = _noteSyncEventBus.events.listen((event) {
      _onNoteSyncEvent(event);
    });
  }

  Class get currentClass => _class;
  Class get initialClass => _initialClass;

  Future<Class> getClassDetails() async {
    _class = await _repository.getClassDetails(_class);
    notifyListeners();
    return _class;
  }

  @override
  void setCourse(String course) {
    _class = _class.copyWith(course: course);
    notifyListeners();
  }

  @override
  void setSchoolYear(String schoolYear) {
    _class = _class.copyWith(schoolYear: schoolYear);
    notifyListeners();
  }

  @override
  void setDayOfWeek(String dayOfWeek) {
    _class = _class.copyWith(dayOfWeek: dayOfWeek);
    notifyListeners();
  }

  @override
  void setTimeBlock(String timeBlock) {
    _class = _class.copyWith(timeBlock: timeBlock);
    notifyListeners();
  }

  void addStudent(String student) {
    if (_class.students.any((s) => s.name == student)) {
      throw Exception('Student already exists');
    }
    _class = _class.copyWith(
      students: [
        ..._class.students,
        Student(name: student),
      ],
    );
    notifyListeners();
  }

  void removeStudent(String student) {
    _class = _class.copyWith(
      students: _class.students.where((s) => s.name != student).toList(),
    );
    notifyListeners();
  }

  void removeNote(Note note) {
    if (note is PendingNote) {
      _class = _class.copyWith(
        pendingNotes: _class.pendingNotes.where((n) => n != note).toList(),
      );
    } else {
      _class = _class.copyWith(
        savedNotes: _class.savedNotes
            .where((n) => n != note && n.id != note.id)
            .toList(),
      );
    }
    notifyListeners();
  }

  void playPendingNote(PendingNote pendingNote) {
    // TODO: Implement playPendingNote
  }

  Future<Result<Class>> _updateClass() async {
    _class = await _repository.updateClass(_class);
    return Result.value(_class);
  }

  Future<void> addVoiceNote(String recordingPath) async {
    try {
      _class = _class.addVoiceNote(recordingPath);
      final pendingNote = _class.pendingNotes.last;
      _class = await _repository.saveLocalPendingNotes(_class);
      unawaited(_syncService.enqueuePendingNote(pendingNote, _class.id!));
      notifyListeners();
    } catch (e) {
      throw Exception(e);
    }
  }

  void _onNoteSyncEvent(NoteSyncEvent event) {
    if (event.type == NoteSyncEventType.syncCompleted) {
      final updatedClass = _class.updateSyncedNote(event.note);
      if (updatedClass != _class) {
        _class = updatedClass;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _syncEventSubscription.cancel();
    super.dispose();
  }
}
