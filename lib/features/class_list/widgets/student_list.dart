import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vm/class_details_vm.dart';

class StudentList extends ConsumerWidget {
  final Provider<ClassDetailsVm> vmProvider;
  const StudentList({super.key, required this.vmProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(vmProvider);
    return const Placeholder();
  }
}