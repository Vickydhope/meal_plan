import 'package:flutter/material.dart';

/// Replaces whatever snackbar is currently showing with a plain message
/// one. Floating/theming comes from [ThemeData.snackBarTheme] (see
/// `main.dart`) — callers just supply the message.
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Replaces whatever snackbar is currently showing with one offering an
/// "Undo" action, returning its controller so callers can react to it
/// closing (e.g. to commit a deferred action once the undo window has
/// passed without [onUndo] having been tapped).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required VoidCallback onUndo,
}) {
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ),
  );
}
