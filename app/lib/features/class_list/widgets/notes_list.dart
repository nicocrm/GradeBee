import 'package:flutter/material.dart';
import '../vm/class_details_vm.dart';

class NotesList extends StatelessWidget {
  final ClassDetailsVM vm;
  const NotesList({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        // TODO: Implement notes list logic
        return ListView(
          children: const [
            ListTile(
              title: Text('Notes for Class'),
              subtitle: Text('Notes list will be implemented soon'),
            ),
          ],
        );
      },
    );
  }
}
