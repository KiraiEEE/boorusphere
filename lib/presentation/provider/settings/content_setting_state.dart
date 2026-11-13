import 'package:boorusphere/data/repository/setting/entity/setting.dart';
import 'package:boorusphere/domain/provider.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:boorusphere/presentation/provider/settings/entity/content_setting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_setting_state.g.dart';

@riverpod
class ContentSettingState extends _$ContentSettingState {
  @override
  ContentSetting build() {
    final repo = ref.read(settingsRepoProvider);
    return ContentSetting(
      blurExplicit: repo.get(Setting.postBlurExplicit, or: true),
      blurTimelineOnly: repo.get(Setting.postBlurTimelineOnly, or: false),
      loadOriginal: repo.get(Setting.postLoadOriginal, or: false),
      videoMuted: repo.get(Setting.videoPlayerMuted, or: false),
      // Users that already opted into non-safe ratings keep seeing them.
      nsfw: repo.get(
        Setting.contentNsfw,
        or:
            repo.get(Setting.searchRating, or: BooruRating.safe) !=
            BooruRating.safe,
      ),
      nsfwConfirmed: repo.get(Setting.contentNsfwConfirmed, or: false),
      hideAi: repo.get(Setting.contentHideAi, or: false),
      hideGay: repo.get(Setting.contentHideGay, or: true),
    );
  }

  Future<void> setHideAi(bool value) async {
    final repo = ref.read(settingsRepoProvider);
    state = state.copyWith(hideAi: value);
    await repo.put(Setting.contentHideAi, value);
  }

  Future<void> setHideGay(bool value) async {
    final repo = ref.read(settingsRepoProvider);
    state = state.copyWith(hideGay: value);
    await repo.put(Setting.contentHideGay, value);
  }

  Future<void> setNsfw(bool value) async {
    final repo = ref.read(settingsRepoProvider);
    state = state.copyWith(
      nsfw: value,
      nsfwConfirmed: state.nsfwConfirmed || value,
    );
    await repo.put(Setting.contentNsfw, value);
    if (value) await repo.put(Setting.contentNsfwConfirmed, true);
  }

  Future<void> setBlurExplicitPost(bool value) async {
    final repo = ref.read(settingsRepoProvider);
    state = state.copyWith(blurExplicit: value);
    await repo.put(Setting.postBlurExplicit, value);
  }

  Future<void> setBlurTimelineOnly(bool value) async {
    final repo = ref.read(settingsRepoProvider);
    state = state.copyWith(blurTimelineOnly: value);
    await repo.put(Setting.postBlurTimelineOnly, value);
  }

  Future<void> setLoadOriginalPost(bool value) async {
    final repo = ref.read(settingsRepoProvider);
    state = state.copyWith(loadOriginal: value);
    await repo.put(Setting.postLoadOriginal, value);
  }

  Future<bool> toggleVideoPlayerMute() async {
    final repo = ref.read(settingsRepoProvider);
    state = state.copyWith(videoMuted: !state.videoMuted);
    await repo.put(Setting.videoPlayerMuted, state.videoMuted);
    return state.videoMuted;
  }
}
