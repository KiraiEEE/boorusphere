import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fullscreen_state.g.dart';

/// Hides the system bars while viewing a post. The screen orientation is
/// left alone: the app stays in portrait (see AndroidManifest.xml).
@riverpod
class FullscreenState extends _$FullscreenState {
  @override
  bool build() {
    ref.onDispose(reset);
    return false;
  }

  Future<void> toggle() async {
    state = !state;
    state
        ? await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive)
        : await unfullscreen();
  }

  Future<void> unfullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void reset() {
    unfullscreen();
  }
}
