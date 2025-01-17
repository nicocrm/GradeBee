import 'package:flutter/material.dart';

import '../command.dart';
import 'spinner_button.dart';

class CommandButton extends StatelessWidget {
  const CommandButton({
    super.key,
    required this.command,
    required this.text,
  });

  final Command0 command;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: command,
      builder: (context, _) {
        if (command.running) {
          return SpinnerButton(text: text);
        }
        return ElevatedButton(
          onPressed: command.execute,
          child: Text(text),
        );
      },
    );
  }
}
