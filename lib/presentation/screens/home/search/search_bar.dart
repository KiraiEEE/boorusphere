import 'package:boorusphere/data/repository/booru/entity/search_sort.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/server_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/screens/home/drawer/home_drawer_controller.dart';
import 'package:boorusphere/presentation/screens/home/search/search_bar_controller.dart';
import 'package:boorusphere/presentation/screens/home/search_session.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/widgets/blur_backdrop.dart';
import 'package:boorusphere/presentation/widgets/favicon.dart';
import 'package:boorusphere/presentation/widgets/nsfw_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeSearchBar extends HookConsumerWidget {
  const HomeSearchBar({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchBar = ref.watch(searchBarControllerProvider);
    final delta = useState([0.0, 0.0]);
    final collapsed = !searchBar.isOpen && delta.value.first > 0;
    final onScrolling = useCallback(() {
      final position = scrollController.position;
      final threshold = innerHeight;
      if (delta.value.first > 0 &&
          position.viewportDimension > position.maxScrollExtent) {
        // reset back to default (!collapsed) because there's nothing to scroll
        delta.value = [0, 0];
        return;
      }

      if (position.extentBefore < threshold ||
          position.extentAfter < threshold) {
        // we're already at the edge of the scrollable content
        // there's no need to change the collapsed state
        return;
      }

      final current = position.pixels;
      final offset = (delta.value.first + current - delta.value.last);
      final boundary = offset.clamp(-threshold, threshold);
      delta.value = [boundary, current];
    }, []);

    useEffect(() {
      scrollController.addListener(onScrolling);
      return () {
        scrollController.removeListener(onScrolling);
      };
    }, []);

    // Reset delta when there's no scrollable widget attached.
    // for example: on new search or while switching server.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (scrollController.hasClients) return;
      if (delta.value.reduce((a, b) => a + b) != 0) {
        delta.value = [0, 0];
      }
    });

    return RepaintBoundary(
      // one flat frosted bar, always blurred
      child: BlurBackdrop(
        sigmaX: 16,
        sigmaY: 16,
        blur: true,
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.scaffoldBackgroundColor.withValues(
              alpha: context.isLightThemed ? 0.7 : 0.75,
            ),
            border: Border(
              top: BorderSide(color: context.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            maintainBottomViewPadding: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (searchBar.isOpen) const _OptionBar(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: collapsed
                      ? const EdgeInsets.fromLTRB(32, 4, 32, 0)
                      : const EdgeInsets.fromLTRB(16, 11, 16, 11),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          _LeadingButton(collapsed: collapsed),
                          if (!searchBar.isOpen)
                            Positioned(
                              right: 9,
                              top: 5,
                              child: _NsfwIndicator(),
                            ),
                        ],
                      ),
                      const Expanded(child: _SearchField()),
                      if (!searchBar.isOpen)
                        _TrailingButton(
                          collapsed: collapsed,
                          scrollController: scrollController,
                        ),
                      if (searchBar.isOpen &&
                          searchBar.value != searchBar.initial)
                        _Button(
                          onTap: searchBar.reset,
                          child: const Icon(Icons.rotate_left),
                        ),
                      if (searchBar.isOpen)
                        _Button(
                          onTap: searchBar.clear,
                          child: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double innerHeight = kBottomNavigationBarHeight + 12;
}

class _SearchField extends HookConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchBar = ref.watch(searchBarControllerProvider);
    final imeIncognito = ref.watch(
      uiSettingStateProvider.select((it) => it.imeIncognito),
    );
    final session = ref.watch(searchSessionProvider);
    final server = ref.watch(serverStateProvider).getById(session.serverId);

    return TextField(
      autofocus: searchBar.isOpen,
      canRequestFocus: searchBar.isOpen,
      enableIMEPersonalizedLearning: !imeIncognito,
      controller: searchBar.textEditingController,
      // the bar itself is the surface: no fill or outline from the app theme
      decoration: InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        hintText: searchBar.value.isEmpty
            ? context.t.searchHint(serverName: server.name)
            : searchBar.value,
        isDense: true,
      ),
      textAlign: searchBar.isOpen ? TextAlign.start : TextAlign.center,
      readOnly: !searchBar.isOpen,
      onSubmitted: (str) {
        searchBar.submit(context, str);
      },
      onTap: searchBar.isOpen ? null : searchBar.open,
      style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
    );
  }
}

class _OptionBar extends ConsumerWidget {
  const _OptionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nsfw = ref.watch(contentSettingStateProvider.select((it) => it.nsfw));
    final sort = ref.watch(serverSettingStateProvider.select((it) => it.sort));
    final session = ref.watch(searchSessionProvider);
    final server = ref.watch(serverStateProvider).getById(session.serverId);
    final sorts = SearchSort.values.where(server.supportsSort);

    String sortLabel(SearchSort it) => switch (it) {
      SearchSort.latest => context.t.sort.latest,
      SearchSort.popular => context.t.sort.popular,
      SearchSort.random => context.t.sort.random,
    };

    IconData sortIcon(SearchSort it) => switch (it) {
      SearchSort.latest => Icons.schedule_rounded,
      SearchSort.popular => Icons.local_fire_department_outlined,
      SearchSort.random => Icons.shuffle_rounded,
    };

    // borderless chips so the options sit flat on the frosted bar
    final flatChips = context.theme.chipTheme.copyWith(
      side: BorderSide.none,
      backgroundColor: Colors.transparent,
      selectedColor: context.colorScheme.secondaryContainer.withValues(
        alpha: 0.7,
      ),
      shape: const StadiumBorder(),
    );

    return ChipTheme(
      data: flatChips,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            FilterChip(
              avatar: Icon(
                nsfw
                    ? Icons.local_fire_department_rounded
                    : Icons.local_fire_department_outlined,
                size: 16,
                color: nsfw ? context.colorScheme.error : null,
              ),
              label: Text(
                '${context.t.nsfw.short}: ${nsfw ? context.t.nsfw.shortOn : context.t.nsfw.shortOff}',
              ),
              selected: nsfw,
              showCheckmark: false,
              onSelected: (it) => setNsfwEnabled(context, ref, it),
            ),
            if (sorts.length > 1) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: context.colorScheme.outlineVariant,
              ),
              for (final it in sorts)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(sortIcon(it), size: 16),
                    label: Text(sortLabel(it)),
                    selected: sort == it,
                    showCheckmark: false,
                    onSelected: (_) => ref
                        .read(serverSettingStateProvider.notifier)
                        .setSort(it),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({this.collapsed = false, required this.onTap, this.child});

  final bool collapsed;
  final void Function() onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: collapsed ? 0.75 : 1,
          child: child,
        ),
      ),
    );
  }
}

class _LeadingButton extends ConsumerWidget {
  const _LeadingButton({this.collapsed = false});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);
    final server = ref.watch(serverStateProvider).getById(session.serverId);
    final searchBar = ref.watch(searchBarControllerProvider);

    return _Button(
      collapsed: collapsed,
      onTap: () {
        if (searchBar.isOpen) {
          searchBar.close();
        } else {
          ref.read(homeDrawerControllerProvider).toggle();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animator) {
          final animation = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: animator, curve: Curves.easeInOutCubic),
          );
          return RotationTransition(
            turns: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: searchBar.isOpen
            ? const Icon(Icons.arrow_back_rounded)
            : server.isAll
            ? const Icon(Icons.all_inclusive_rounded, size: 18)
            : Favicon(
                key: ValueKey(server.homepage),
                url: server.homepage,
                iconSize: 18,
              ),
      ),
    );
  }
}

/// A small red dot on the server icon while NSFW is on, nothing in safe mode.
class _NsfwIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nsfw = ref.watch(contentSettingStateProvider.select((it) => it.nsfw));
    if (!nsfw) return const SizedBox.shrink();
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: context.colorScheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _TrailingButton extends ConsumerWidget {
  const _TrailingButton({this.collapsed = false, this.scrollController});

  final bool collapsed;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = context.iconTheme.size ?? 24;
    final grid = ref.watch(uiSettingStateProvider.select((ui) => ui.grid));

    backToTop() {
      scrollController?.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }

    return _Button(
      onTap: collapsed
          ? backToTop
          : ref.read(uiSettingStateProvider.notifier).cycleGrid,
      collapsed: collapsed,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animator) {
            final animation = Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: animator, curve: Curves.easeInOutCubic),
            );
            return RotationTransition(
              turns: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: collapsed
              ? const Icon(Icons.arrow_upward_rounded)
              : Icon(key: ValueKey(grid), Icons.grid_view, size: 20),
        ),
      ),
    );
  }
}
