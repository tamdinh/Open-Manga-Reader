import 'dart:async';

bool isBrowserFullscreen() => false;

Future<bool> toggleBrowserFullscreen(bool enter) async => false;

StreamSubscription? listenBrowserFullscreenChanges(
  void Function(bool isFullscreen) callback,
) =>
    null;
