import 'package:flutter/material.dart';

mixin ErrorMixin<T extends StatefulWidget> on State<T> {
  /// Show a snackbar if error is not empty.  [onClosed] is called when the
  /// snackbar is closed, unless the snackbar is removed programmatically.
  void showErrorSnackbar(String error, [Function()? onClosed]) {
    if (error.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        final controller = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        if (onClosed != null) {
          controller.closed.then((reason) {
            if (reason != SnackBarClosedReason.remove) {
              onClosed();
            }
          });
        }
      });
    }
  }

  Widget buildErrorText(String error) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        error,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}
