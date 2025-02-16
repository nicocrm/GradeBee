import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'class_details_vm.dart';

class RecordNoteDialogVM extends ChangeNotifier {
  final ClassDetailsVM classDetailsVM;
  final _record = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  late Future<void> _startingRecording;
  bool _isSaving = false;
  String? _error;

  int get seconds => _seconds;
  Future<void> get startingRecording => _startingRecording;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get hasError => _error != null;

  RecordNoteDialogVM({required this.classDetailsVM}) {
    _startingRecording = startRecording();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      notifyListeners();
    });
  }

  Future<void> startRecording() async {
    if (await _record.hasPermission()) {
      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
        ),
        path:
            'voice_note_${DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '')}.m4a',
      );
      _startTimer();
    }
  }

  Future<bool> saveRecording() async {
    try {
      _isSaving = true;
      _error = null;
      notifyListeners();

      final path = await _record.stop();
      await classDetailsVM.addVoiceNote(path!);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void cancelRecording() {
    _record.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _record.dispose();
    super.dispose();
  }
}
