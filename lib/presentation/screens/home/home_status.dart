import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/data/repository/booru/entity/booru_error.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/booru/entity/fetch_result.dart';
import 'package:boorusphere/presentation/provider/booru/entity/page_data.dart';
import 'package:boorusphere/presentation/provider/booru/page_state.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:boorusphere/presentation/provider/settings/server_setting_state.dart';
import 'package:boorusphere/presentation/routes/app_router.gr.dart';
import 'package:boorusphere/presentation/screens/home/search_session.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/utils/extensions/strings.dart';
import 'package:boorusphere/presentation/widgets/error_info.dart';
import 'package:boorusphere/presentation/widgets/notice_card.dart';
import 'package:boorusphere/presentation/widgets/nsfw_toggle.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeStatus extends HookConsumerWidget {
  const HomeStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageState = ref.watch(pageStateProvider);
    final hidden = pageState.data.hidden;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (pageState) {
        IdleFetchResult() => const SizedBox.shrink(),
        DataFetchResult() => Column(
            key: const ValueKey('data'),
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: ref.read(pageStateProvider.notifier).loadMore,
                child: Text(context.t.loadMore),
              ),
              if (hidden > 0) _HiddenCount(hidden),
            ],
          ),
        LoadingFetchResult() => const SizedBox(
            key: ValueKey('loading'),
            height: 56,
            child: Center(child: RefreshProgressIndicator()),
          ),
        ErrorFetchResult(:final data, :final error, :final stackTrace) =>
          _ErrorStatus(
            key: const ValueKey('error'),
            data: data,
            error: error,
            stackTrace: stackTrace,
          ),
      },
    );
  }
}

class _HiddenCount extends StatelessWidget {
  const _HiddenCount(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 14,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            context.t.pageStatus.hidden(n: count),
            style: context.theme.textTheme.labelMedium
                ?.copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorStatus extends ConsumerWidget {
  const _ErrorStatus({
    super.key,
    required this.data,
    this.error,
    this.stackTrace,
  });

  final PageData data;
  final Object? error;
  final StackTrace? stackTrace;

  Object? buildError(BuildContext context, Server server) {
    final e = error;
    if (e is DioException && e.response?.statusCode != null) {
      return context.t.pageStatus
          .httpError(serverName: server.name)
          .withDioExceptionCode(e);
    } else if (e == BooruError.empty) {
      return data.option.query.isEmpty
          ? context.t.pageStatus.noResult(n: data.posts.length)
          : context.t.pageStatus
              .noResultForQuery(n: data.posts.length, query: data.option.query);
    } else if (e == BooruError.tagsBlocked) {
      return context.t.pageStatus.blocked(query: data.option.query);
    } else {
      return e;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);
    final server = ref.watch(serverStateProvider).getById(session.serverId);
    final nsfw = ref.watch(contentSettingStateProvider.select((it) => it.nsfw));
    final retry = ref.read(pageStateProvider.notifier).load;

    if (error == BooruError.nsfwDisabled) {
      return _Notice(
        icon: Icons.eighteen_up_rating_outlined,
        title: context.t.nsfw.serverHidden(serverName: server.name),
        desc: context.t.nsfw.serverHiddenDesc,
        actions: [
          FilledButton(
            onPressed: () => setNsfwEnabled(context, ref, true),
            child: Text(context.t.nsfw.enable),
          ),
        ],
      );
    }

    if (error == BooruError.authRequired) {
      return _Notice(
        icon: Icons.key_rounded,
        title: context.t.pageStatus.authRequired(serverName: server.name),
        desc: context.t.pageStatus.authRequiredDesc,
        actions: [
          OutlinedButton(onPressed: retry, child: Text(context.t.retry)),
          FilledButton(
            onPressed: () =>
                context.router.push(ServerEditorRoute(server: server)),
            child: Text(context.t.pageStatus.addApiKey),
          ),
        ],
      );
    }

    final rating =
        ref.watch(serverSettingStateProvider.select((it) => it.searchRating));
    final canWidenRating = error == BooruError.empty && data.posts.isEmpty;

    return Center(
      child: NoticeCard(
        icon: const Icon(Icons.search_off_rounded),
        margin: const EdgeInsets.all(16),
        children: Column(
          children: [
            ErrorInfo(
              error: buildError(context, server),
              stackTrace: stackTrace,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canWidenRating && !nsfw)
                  OutlinedButton(
                    onPressed: () => setNsfwEnabled(context, ref, true),
                    child: Text(context.t.nsfw.enable),
                  )
                else if (canWidenRating && rating != BooruRating.all)
                  OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(serverSettingStateProvider.notifier)
                          .setRating(BooruRating.all);
                      if (context.mounted) unawaited(retry());
                    },
                    child: Text(
                      '${context.t.rating.title}: ${context.t.rating.all}',
                    ),
                  ),
                FilledButton.tonal(
                  onPressed: retry,
                  child: Text(context.t.retry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.desc,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String desc;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: NoticeCard(
        icon: Icon(icon, size: 32, color: context.colorScheme.primary),
        margin: const EdgeInsets.all(16),
        children: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyMedium
                  ?.copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
