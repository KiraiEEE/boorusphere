import 'dart:async';

import 'package:boorusphere/data/repository/booru/entity/booru_error.dart';
import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/data/repository/tags_blocker/blacklist.dart';
import 'package:boorusphere/domain/provider.dart';
import 'package:boorusphere/presentation/provider/booru/entity/fetch_result.dart';
import 'package:boorusphere/presentation/provider/booru/entity/page_data.dart';
import 'package:boorusphere/presentation/provider/search_history_state.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:boorusphere/presentation/provider/settings/server_setting_state.dart';
import 'package:boorusphere/presentation/provider/tags_blocker_state.dart';
import 'package:boorusphere/presentation/screens/home/search_session.dart';
import 'package:boorusphere/presentation/utils/extensions/post.dart';
import 'package:boorusphere/utils/extensions/string.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'page_state.g.dart';

/// The rating that is actually sent to servers, safe mode always wins.
@riverpod
BooruRating effectiveRating(Ref ref) {
  final nsfw = ref.watch(contentSettingStateProvider.select((it) => it.nsfw));
  final rating =
      ref.watch(serverSettingStateProvider.select((it) => it.searchRating));
  return nsfw ? rating : BooruRating.safe;
}

@riverpod
class PageState extends _$PageState {
  PageState({this.session = const SearchSession()});

  final SearchSession session;

  /// Every post fetched so far, including hidden ones
  final _posts = <Post>[];
  final _ids = <int>{};
  int _page = 0;
  int _generation = 0;

  @override
  FetchResult<PageData> build() {
    _page = 0;
    _posts.clear();
    _ids.clear();

    // Re-filter what we already have when the rules change, no refetch needed
    ref.listen(blacklistProvider(session.serverId), (_, __) => _refilter());
    ref.listen(
      contentSettingStateProvider.select((it) => it.nsfw),
      (prev, next) {
        if (prev == next) return;
        // ratings are applied server-side too, so start fresh
        unawaited(update((it) => it.copyWith(clear: true)));
      },
    );

    return const FetchResult.idle(PageData());
  }

  Server get _server {
    return ref.read(serverStateProvider).getById(session.serverId);
  }

  bool get _nsfw => ref.read(contentSettingStateProvider).nsfw;

  Blacklist get _blacklist => ref.read(blacklistProvider(session.serverId));

  bool _isVisible(Post post, Blacklist blacklist, bool nsfw) {
    if (!nsfw && post.rating.isNsfw) return false;
    return !blacklist.matches(post);
  }

  ({List<Post> visible, int hidden}) _filtered() {
    final blacklist = _blacklist;
    final nsfw = _nsfw;
    final visible = _posts.where((it) => _isVisible(it, blacklist, nsfw));
    final list = List<Post>.unmodifiable(visible);
    return (visible: list, hidden: _posts.length - list.length);
  }

  void _refilter() {
    if (!ref.mounted || _posts.isEmpty) return;
    final res = _filtered();
    final data = state.data.copyWith(posts: res.visible, hidden: res.hidden);
    state = switch (state) {
      ErrorFetchResult(:final error, :final stackTrace) =>
        FetchResult.error(data, error: error, stackTrace: stackTrace),
      LoadingFetchResult() => FetchResult.loading(data),
      IdleFetchResult() => FetchResult.idle(data),
      DataFetchResult() => FetchResult.data(data),
    };
  }

  Future<void> update(PageOption Function(PageOption) updater) async {
    final newOption = updater(state.data.option);
    state = state.copyWith(data: state.data.copyWith(option: newOption));
    await load();
  }

  Future<void> load() async {
    final server = _server;
    if (server == Server.empty) return;

    if (server.nsfw && !_nsfw) {
      _posts.clear();
      _ids.clear();
      state = FetchResult.error(
        state.data.copyWith(posts: const [], hidden: 0),
        error: BooruError.nsfwDisabled,
      );
      return;
    }

    final query = state.data.option.query;
    if (query.toWordList().any(_blacklist.blocksTag)) {
      state = FetchResult.error(state.data, error: BooruError.tagsBlocked);
      return;
    }

    if (query.isNotEmpty) {
      await ref.read(searchHistoryStateProvider.notifier).save(query, server);
      if (!ref.mounted) return;
    }

    final settings = ref.read(serverSettingStateProvider);
    final option = state.data.option.copyWith(
      limit: settings.postLimit,
      searchRating: ref.read(effectiveRatingProvider),
    );

    if (option.clear) {
      _page = 0;
      _posts.clear();
      _ids.clear();
    }

    // ignore results of a superseded request (e.g. rapid refresh)
    final generation = ++_generation;
    final initial = _filtered();
    state = FetchResult.loading(state.data.copyWith(
      posts: initial.visible,
      hidden: initial.hidden,
      option: option,
    ));

    try {
      final repo = ref.read(imageboardRepoProvider(server));
      // keep paging while every fetched post is hidden by filters
      for (var attempt = 0; attempt <= 3; attempt++) {
        final res = await repo.getPage(option, _page);
        if (!ref.mounted || generation != _generation) return;
        if (res.isEmpty) {
          state = FetchResult.error(state.data, error: BooruError.empty);
          return;
        }
        _page++;

        final before = state.data.posts.length;
        _posts.addAll(res.where((it) => _ids.add(it.id)));
        final filtered = _filtered();
        final data = state.data.copyWith(
          posts: filtered.visible,
          hidden: filtered.hidden,
        );
        if (filtered.visible.length > before || attempt == 3) {
          state = FetchResult.data(data);
          return;
        }
        state = FetchResult.loading(data);
      }
    } catch (err, stack) {
      if (!ref.mounted || generation != _generation) return;
      state = FetchResult.error(state.data, error: err, stackTrace: stack);
    }
  }

  Future<void> loadMore() async {
    if (state is! DataFetchResult) return;

    await update((it) => it.copyWith(clear: false));
  }
}
