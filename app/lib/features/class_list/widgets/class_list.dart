import '../models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClassList extends StatelessWidget {
  final List<Class> classes;

  const ClassList({super.key, required this.classes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 80, // Add padding at bottom to prevent FAB overlap
      ),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final class_ = classes[index];
        return ListTile(
          title: Text(class_.course),
          subtitle:
              Text('${class_.dayOfWeek ?? 'No day set'} - ${class_.timeBlock}'),
          onTap: () => {context.push('/class_list/details', extra: class_)},
        );
      },
    );
  }
}
