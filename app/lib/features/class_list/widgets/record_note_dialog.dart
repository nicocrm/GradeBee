import 'package:flutter/material.dart';
import '../vm/class_details_vm.dart';
import '../vm/record_note_dialog_vm.dart';

class RecordNoteDialog extends StatefulWidget {
  final ClassDetailsVM viewModel;

  const RecordNoteDialog({super.key, required this.viewModel});

  @override
  State<RecordNoteDialog> createState() => _RecordNoteDialogState();
}

class _RecordNoteDialogState extends State<RecordNoteDialog> {
  late final RecordNoteDialogVM _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = RecordNoteDialogVM(classDetailsVM: widget.viewModel);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _viewModel.startingRecording,
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
          return PopScope(
              canPop: false,
              child: RecordingAlertDialog(
                viewModel: _viewModel,
              ));
        });
  }
}

class RecordingAlertDialog extends StatelessWidget {
  final RecordNoteDialogVM viewModel;

  const RecordingAlertDialog({
    super.key,
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
      listenable: viewModel,
      builder: (context, child) {
        Widget content;
        if (viewModel.error != null) {
          content = Text(
            viewModel.error.toString(),
            style: const TextStyle(color: Colors.red),
          );
        } else if (viewModel.isSaving) {
          content = const CircularProgressIndicator();
        } else {
          content = Text(
            _formatTime(viewModel.seconds),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          );
        }

        return AlertDialog(
          title: const Text('Recording - Press Save when done'),
          content: Center(child: content),
          actions: [
            TextButton(
              onPressed: () {
                viewModel.cancelRecording();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await viewModel.saveRecording();
                if (context.mounted && success) {
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
