import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fullscreen_state.g.dart';

@riverpod
class FullscreenState extends _$FullscreenState {
  List<DeviceOrientation> _lastOrientations = [];

  @override
  bool build() {
    ref.onDispose(reset);
    _lastOrientations = [];
    return false;
  }

  Future<void> toggle({bool shouldLandscape = false}) async {
    state = !state;
    final orientations = state && shouldLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : <DeviceOrientation>[];

    if (orientations != _lastOrientations) {
      _lastOrientations = orientations;
      await SystemChrome.setPreferredOrientations(orientations);
    }

    state
        ? await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive)
        : await unfullscreen();
  }

  Future<void> unfullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void reset() {
    SystemChrome.setPreferredOrientations([]);
    unfullscreen();
  }
}
