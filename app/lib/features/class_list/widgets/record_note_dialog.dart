import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../vm/class_details_vm.dart';

class RecordNoteDialog extends StatefulWidget {
  final ClassDetailsVM viewModel;

  const RecordNoteDialog({super.key, required this.viewModel});

  @override
  State<RecordNoteDialog> createState() => _RecordNoteDialogState();
}

class _RecordNoteDialogState extends State<RecordNoteDialog> {
  late Timer _timer;
  final _record = AudioRecorder();
  int _seconds = 0;
  late Future<void> _startingRecording;

  @override
  void initState() {
    super.initState();
    _startingRecording = startRecording();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> startRecording() async {
    if (await _record.hasPermission()) {
      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
        ),
        path: 'voice_note.m4a',
      );
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _startingRecording,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text(snapshot.error.toString()),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return RecordingAlertDialog(
            seconds: _seconds,
            record: _record,
            timer: _timer,
            viewModel: widget.viewModel,
          );
        });
  }
}

class RecordingAlertDialog extends StatelessWidget {
  final int seconds;
  final AudioRecorder record;
  final Timer timer;
  final ClassDetailsVM viewModel;

  const RecordingAlertDialog({
    super.key,
    required this.seconds,
    required this.record,
    required this.timer,
    required this.viewModel,
  });

  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel.addVoiceNoteCommand,
      builder: (context, child) {
        Widget content;
        if (viewModel.addVoiceNoteCommand.error != null) {
          content = Text(
            viewModel.addVoiceNoteCommand.error!.error.toString(),
            style: const TextStyle(color: Colors.red),
          );
        } else if (viewModel.addVoiceNoteCommand.running) {
          content = const CircularProgressIndicator();
        } else {
          content = Text(
            _formatTime(seconds),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          );
        }

        return AlertDialog(
          title: const Text('Recording - Press Save when done'),
          content: Center(child: content),
          actions: [
            TextButton(
              onPressed: () {
                record.cancel();
                timer.cancel();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final path = await record.stop();
                timer.cancel();
                await viewModel.addVoiceNoteCommand.execute(path!);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
