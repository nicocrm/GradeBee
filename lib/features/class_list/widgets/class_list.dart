import 'package:class_database/features/class_list/models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClassList extends StatelessWidget {
  final List<Class> classes;

  const ClassList({super.key, required this.classes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final class_ = classes[index];
        return ListTile(
          title: Text(class_.course),
          onTap: () => {context.go('/class_list/details', extra: class_)},
        );
      },
    );
  }
}
