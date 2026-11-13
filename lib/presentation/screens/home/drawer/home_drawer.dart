import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/app_updater.dart';
import 'package:boorusphere/presentation/provider/app_versions/app_versions_state.dart';
import 'package:boorusphere/presentation/provider/booru/page_state.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/routes/app_router.gr.dart';
import 'package:boorusphere/presentation/screens/home/drawer/home_drawer_controller.dart';
import 'package:boorusphere/presentation/screens/home/search_session.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/widgets/favicon.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key, required this.maxWidth});

  final double maxWidth;

  static const _radius = BorderRadius.only(
    topRight: Radius.circular(25),
    bottomRight: Radius.circular(25),
  );

  @override
  Widget build(BuildContext context) {
    final background =
        context.theme.drawerTheme.backgroundColor ??
        context.colorScheme.surfaceContainerLow;
    // Solid surface on purpose: a live blur has to re-sample the whole
    // timeline on every frame of the slide, which stutters on most phones.
    return Material(
      color: background,
      borderRadius: _radius,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: constraints.copyWith(
                minHeight: constraints.maxHeight,
                maxHeight: double.infinity,
                maxWidth: maxWidth,
              ),
              child: IntrinsicHeight(
                child: SafeArea(
                  child: ListTileTheme(
                    data: context.theme.listTileTheme.copyWith(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [_Header(), _ServerSelection()],
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: _Footer(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HomeTile(),
        ListTile(
          title: Text(context.t.downloads.title),
          leading: const Icon(Icons.cloud_download),
          onTap: () => context.router.push(DownloadsRoute(session: session)),
        ),
        ListTile(
          title: Text(context.t.favorites.title),
          leading: const Icon(Icons.favorite_border),
          onTap: () => context.router.push(FavoritesRoute(session: session)),
        ),
        ListTile(
          title: Text(context.t.servers.title),
          leading: const Icon(Icons.public),
          onTap: () => context.router.push(ServerRoute(session: session)),
        ),
        ListTile(
          title: Text(context.t.tagsBlocker.title),
          leading: const Icon(Icons.block),
          onTap: () => context.router.push(const TagsBlockerRoute()),
        ),
        ListTile(
          title: Text(context.t.settings.title),
          leading: const Icon(Icons.settings),
          onTap: () => context.router.push(const SettingsRoute()),
        ),
        const AppVersionTile(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 30, 15, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Boorusphere!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200),
          ),
          _ThemeSwitcherButton(),
        ],
      ),
    );
  }
}

class _ThemeSwitcherButton extends ConsumerWidget {
  IconData themeIconOf(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons.brightness_2;
      case ThemeMode.light:
        return Icons.brightness_high;
      default:
        return Icons.brightness_auto;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(
      uiSettingStateProvider.select((ui) => ui.themeMode),
    );

    return IconButton(
      icon: Icon(themeIconOf(theme)),
      onPressed: () =>
          ref.read(uiSettingStateProvider.notifier).cycleThemeMode(),
    );
  }
}

class AppVersionTile extends ConsumerWidget {
  const AppVersionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appVersions = ref.watch(appVersionsStateProvider);
    final updateProgress = ref.watch(appUpdateProgressProvider);

    final currentTile = ListTile(
      title: appVersions.maybeWhen(
        data: (data) => Text('Boorusphere ${data.current}'),
        orElse: () => const Text('Boorusphere'),
      ),
      leading: const Icon(Icons.info_outline),
      onTap: () => context.router.push(const AboutRoute()),
    );

    return appVersions.maybeWhen(
      data: (data) {
        if (!data.latest.isNewerThan(data.current)) return currentTile;
        if (updateProgress.status.isDownloading) {
          return ListTile(
            title: Text(context.t.updater.available(version: '${data.latest}')),
            leading: const SizedBox(
              height: 24,
              width: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            subtitle: Text(
              context.t.updater.progress(progress: updateProgress.progress),
            ),
            onTap: () => context.router.push(const AboutRoute()),
          );
        }
        return ListTile(
          title: Text(context.t.updater.available(version: '${data.latest}')),
          leading: Icon(Icons.info_outline, color: Colors.pink.shade300),
          subtitle: Text(
            updateProgress.status.isDownloaded
                ? context.t.updater.install
                : context.t.changelog.view,
          ),
          onTap: () {
            context.router.push(const AboutRoute());
          },
        );
      },
      orElse: () => currentTile,
    );
  }
}

class _HomeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);
    return Visibility(
      visible: session.query.isNotEmpty,
      child: ListTile(
        title: Text(context.t.home),
        leading: const Icon(Icons.home_outlined),
        onTap: () {
          ref.read(homeDrawerControllerProvider).close();
          context.router.pushAndPopUntil(
            HomeRoute(session: session.copyWith(query: '')),
            predicate: (r) => false,
          );
        },
      ),
    );
  }
}

class _ServerSelection extends ConsumerWidget {
  const _ServerSelection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allServers = ref.watch(serverStateProvider);
    final nsfw = ref.watch(contentSettingStateProvider.select((it) => it.nsfw));
    final session = ref.watch(searchSessionProvider);
    final serverActive = allServers.getById(session.serverId);
    final hideAi = ref.watch(
      contentSettingStateProvider.select((it) => it.hideAi),
    );
    final servers = [
      if (allServers.length > 1) Server.allServers,
      ...allServers.where((it) => (nsfw || !it.nsfw) && !(hideAi && it.ai)),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: servers.map((it) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
            child: ListTile(
              title: Text(it.isAll ? context.t.servers.allServers : it.name),
              trailing: it.nsfw
                  ? Text(
                      context.t.nsfw.badge,
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
              leading: it.isAll
                  ? const Icon(Icons.all_inclusive_rounded, size: 21)
                  : Favicon(
                      url: it.homepage,
                      shape: BoxShape.circle,
                      iconSize: 21,
                    ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              selected: it.id == serverActive.id,
              selectedTileColor: context.colorScheme.secondaryContainer,
              selectedColor: context.colorScheme.onSecondaryContainer,
              onTap: () {
                ref.read(homeDrawerControllerProvider).close().then((value) {
                  if (!context.mounted) return;
                  if (it.id != serverActive.id) {
                    context.router.push(
                      HomeRoute(session: session.copyWith(serverId: it.id)),
                    );
                  } else {
                    ref
                        .read(pageStateProvider.notifier)
                        .update((it) => it.copyWith(clear: true));
                  }
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
