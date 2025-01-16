import 'package:flutter/material.dart';

class SpinnerButton extends StatelessWidget {
  final String text;

  const SpinnerButton({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(dimension: 12, child: CircularProgressIndicator()),
          const SizedBox(width: 4),
          Text(text),
        ],
      ),
    );
  }
}
