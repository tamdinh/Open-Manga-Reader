import 'dart:async';
import 'web_fullscreen_helper_stub.dart'
    if (dart.library.js_interop) 'web_fullscreen_helper_web.dart';

class WebFullscreenHelper {
  static bool get isFullscreen => isBrowserFullscreen();

  static Future<bool> toggleFullscreen(bool enter) =>
      toggleBrowserFullscreen(enter);

  static StreamSubscription? listenFullscreenChanges(
    void Function(bool isFullscreen) callback,
  ) =>
      listenBrowserFullscreenChanges(callback);
}
