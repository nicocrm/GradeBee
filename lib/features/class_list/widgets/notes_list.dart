import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vm/class_details_vm.dart';

class NotesList extends ConsumerWidget {
  final ClassDetailsVmProvider vmProvider;
  const NotesList({super.key, required this.vmProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(vmProvider);
    // TODO: Implement notes list logic
    return ListView(
      children: [
        ListTile(
          title: Text('Notes for Class'),
          subtitle: Text('Notes list will be implemented soon'),
        ),
      ],
    );
  }
}
