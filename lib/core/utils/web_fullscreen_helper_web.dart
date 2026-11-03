import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

bool isBrowserFullscreen() {
  try {
    return web.document.fullscreenElement != null;
  } catch (e) {
    debugPrint('Check browser fullscreen error: $e');
    return false;
  }
}

Future<bool> toggleBrowserFullscreen(bool enter) async {
  try {
    if (enter) {
      final promise = web.document.documentElement?.requestFullscreen();
      if (promise != null) {
        await promise.toDart;
      }
      return isBrowserFullscreen();
    } else {
      if (web.document.fullscreenElement != null) {
        final promise = web.document.exitFullscreen();
        await promise.toDart;
      }
      return isBrowserFullscreen();
    }
  } catch (e) {
    debugPrint('Toggle browser fullscreen error: $e');
    return isBrowserFullscreen();
  }
}

StreamSubscription? listenBrowserFullscreenChanges(
  void Function(bool isFullscreen) callback,
) {
  try {
    return web.EventStreamProviders.fullscreenChangeEvent
        .forTarget(web.document)
        .listen((_) {
      callback(isBrowserFullscreen());
    });
  } catch (e) {
    debugPrint('Listen browser fullscreen error: $e');
    return null;
  }
}
