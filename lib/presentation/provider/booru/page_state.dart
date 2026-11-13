import 'dart:async';
import 'dart:math';

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

/// The rating that is actually sent to servers: the NSFW switch alone
/// decides, on shows every rating and off shows safe posts only.
@riverpod
BooruRating effectiveRating(Ref ref) {
  final nsfw = ref.watch(contentSettingStateProvider.select((it) => it.nsfw));
  return nsfw ? BooruRating.all : BooruRating.safe;
}

@riverpod
class PageState extends _$PageState {
  PageState({this.session = const SearchSession()});

  final SearchSession session;

  /// Every post fetched so far, including hidden ones
  final _posts = <Post>[];

  /// "serverId#postId", ids alone collide between servers
  final _ids = <String>{};
  int _page = 0;
  int _generation = 0;

  /// All-servers mode: next page and end of results, per server
  final _pages = <String, int>{};
  final _exhausted = <String>{};

  bool get _isAll => session.serverId == Server.allServersId;

  void _reset() {
    _page = 0;
    _posts.clear();
    _ids.clear();
    _pages.clear();
    _exhausted.clear();
  }

  @override
  FetchResult<PageData> build() {
    _reset();

    // Re-filter what we already have when the rules change, no refetch needed
    if (_isAll) {
      ref.listen(tagsBlockerStateProvider, (_, _) => _refilter());
    } else {
      ref.listen(blacklistProvider(session.serverId), (_, _) => _refilter());
    }
    ref.listen(
      contentSettingStateProvider.select((it) => it.hideAi),
      (_, _) => _refilter(),
    );
    ref.listen(
      contentSettingStateProvider.select((it) => it.hideGay),
      (_, _) => _refilter(),
    );
    ref.listen(serverSettingStateProvider.select((it) => it.sort), (
      prev,
      next,
    ) {
      if (prev == next) return;
      unawaited(update((it) => it.copyWith(clear: true)));
    });
    ref.listen(contentSettingStateProvider.select((it) => it.nsfw), (
      prev,
      next,
    ) {
      if (prev == next) return;
      // ratings are applied server-side too, so start fresh
      unawaited(update((it) => it.copyWith(clear: true)));
    });

    return const FetchResult.idle(PageData());
  }

  Server get _server {
    return ref.read(serverStateProvider).getById(session.serverId);
  }

  bool get _nsfw => ref.read(contentSettingStateProvider).nsfw;

  Blacklist get _blacklist => ref.read(blacklistProvider(session.serverId));

  static const _aiTags = {
    'ai-generated',
    'ai_generated',
    'ai-assisted',
    'ai_assisted',
    'ai_art',
    'ai-created',
    'ai_created',
    'stable_diffusion',
    'novelai',
    'midjourney',
    'nijijourney',
  };

  static bool isAiGenerated(Post post) =>
      post.allTags.any((it) => _aiTags.contains(it.toLowerCase()));

  static const _gayTags = {
    'yaoi',
    'gay',
    'gay_male',
    'gay_sex',
    'gay_couple',
    'bara',
    'male/male',
    'male_on_male',
    'malexmale',
    'male_x_male',
    'boys_love',
    'shounen_ai',
    'shonen_ai',
  };

  static bool isGay(Post post) =>
      post.allTags.any((it) => _gayTags.contains(it.toLowerCase()));

  ({List<Post> visible, int hidden}) _filtered() {
    final content = ref.read(contentSettingStateProvider);
    final servers = {for (final it in ref.read(serverStateProvider)) it.id: it};
    final blacklists = <String, Blacklist>{};
    Blacklist blacklistOf(Post post) {
      final id = _isAll ? post.serverId : session.serverId;
      return blacklists.putIfAbsent(id, () => ref.read(blacklistProvider(id)));
    }

    final visible = _posts.where((it) {
      if (!content.nsfw && it.rating.isNsfw) return false;
      // everything on an AI-only server counts as AI content
      if (content.hideAi &&
          ((servers[it.serverId]?.ai ?? false) || isAiGenerated(it))) {
        return false;
      }
      if (content.hideGay && isGay(it)) return false;
      return !blacklistOf(it).matches(it);
    });
    final list = List<Post>.unmodifiable(visible);
    return (visible: list, hidden: _posts.length - list.length);
  }

  void _refilter() {
    if (!ref.mounted || _posts.isEmpty) return;
    final res = _filtered();
    final data = state.data.copyWith(posts: res.visible, hidden: res.hidden);
    state = switch (state) {
      ErrorFetchResult(:final error, :final stackTrace) => FetchResult.error(
        data,
        error: error,
        stackTrace: stackTrace,
      ),
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
      _reset();
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
      sort: settings.sort,
    );

    if (option.clear) _reset();

    // ignore results of a superseded request (e.g. rapid refresh)
    final generation = ++_generation;
    final initial = _filtered();
    state = FetchResult.loading(
      state.data.copyWith(
        posts: initial.visible,
        hidden: initial.hidden,
        option: option,
      ),
    );

    try {
      // keep paging while every fetched post is hidden by filters
      for (var attempt = 0; attempt <= 3; attempt++) {
        final res = _isAll
            ? await _fetchAll(option)
            : await ref
                  .read(imageboardRepoProvider(server))
                  .getPage(option, _page);
        if (!ref.mounted || generation != _generation) return;
        if (res.isEmpty) {
          state = FetchResult.error(state.data, error: BooruError.empty);
          return;
        }
        _page++;

        final before = state.data.posts.length;
        _posts.addAll(res.where((it) => _ids.add('${it.serverId}#${it.id}')));
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

  /// Servers searched in all-servers mode
  List<Server> get _sources {
    final content = ref.read(contentSettingStateProvider);
    return ref
        .read(serverStateProvider)
        .where((it) => (content.nsfw || !it.nsfw) && !(content.hideAi && it.ai))
        .toList();
  }

  /// One page from every server at once, mixed in turns so no single
  /// server floods the timeline. Servers that fail or run out are skipped.
  Future<List<Post>> _fetchAll(PageOption option) async {
    final sources = _sources
        .where((it) => !_exhausted.contains(it.id))
        .toList();
    if (sources.isEmpty) return const [];

    final perServer = (option.limit / sources.length)
        .ceil()
        .clamp(10, max(10, option.limit))
        .toInt();
    final opt = option.copyWith(limit: perServer);
    final errors = <Object>[];
    final results = await Future.wait(
      sources.map((it) async {
        try {
          final page = _pages[it.id] ?? 0;
          final res = await ref
              .read(imageboardRepoProvider(it))
              .getPage(opt, page)
              .timeout(const Duration(seconds: 20))
              .then((it) => it.toList());
          _pages[it.id] = page + 1;
          if (res.isEmpty) _exhausted.add(it.id);
          return res;
        } catch (err) {
          errors.add(err);
          _exhausted.add(it.id);
          return const <Post>[];
        }
      }),
    );

    final longest = results.fold(0, (m, it) => max(m, it.length));
    final mixed = [
      for (var i = 0; i < longest; i++)
        for (final res in results)
          if (i < res.length) res[i],
    ];
    if (mixed.isEmpty && errors.length == sources.length) throw errors.first;
    return mixed;
  }

  Future<void> loadMore() async {
    if (state is! DataFetchResult) return;

    await update((it) => it.copyWith(clear: false));
  }
}
