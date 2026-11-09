import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/booru/post_headers_factory.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:boorusphere/presentation/provider/tags_blocker_state.dart';
import 'package:boorusphere/presentation/routes/app_router.gr.dart';
import 'package:boorusphere/presentation/screens/home/search_session.dart';
import 'package:boorusphere/presentation/utils/entity/pixel_size.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/utils/extensions/images.dart';
import 'package:boorusphere/presentation/utils/extensions/post.dart';
import 'package:boorusphere/presentation/widgets/glass.dart';
import 'package:boorusphere/presentation/widgets/styled_overlay_region.dart';
import 'package:boorusphere/utils/extensions/string.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

@RoutePage()
class PostDetailsPage extends HookConsumerWidget with ClipboardMixins {
  const PostDetailsPage({super.key, required this.post, required this.session});
  final Post post;
  final SearchSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(postHeadersFactoryProvider(post));
    final selected = useState(<String>[]);
    final queryTags = useMemoized(() => session.query.toWordList().toSet());

    void toggle(String tag) {
      HapticFeedback.selectionClick();
      selected.value = selected.value.contains(tag)
          ? [...selected.value.where((it) => it != tag)]
          : [...selected.value, tag];
    }

    void search(Iterable<String> tags) {
      final newQuery = {...tags}.join(' ');
      if (newQuery.isEmpty) return;
      context.router.push(
        HomeRoute(session: session.copyWith(query: newQuery)),
      );
    }

    void block(Iterable<String> tags) {
      final list = tags.toList();
      ref.read(tagsBlockerStateProvider.notifier).pushAll(tags: list);
      selected.value = [...selected.value.where((it) => !list.contains(it))];
      context.scaffoldMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.t.actionTag.blocked),
            duration: const Duration(seconds: 2),
          ),
        );
    }

    Future<void> showTagActions(String tag) async {
      HapticFeedback.mediumImpact();
      await showModalBottomSheet(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  tag.replaceAll('_', ' '),
                  textAlign: TextAlign.center,
                  style: sheetContext.theme.textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search_rounded),
                title: Text(sheetContext.t.actionTag.search),
                onTap: () {
                  sheetContext.navigator.pop();
                  search([tag]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(sheetContext.t.actionTag.append),
                onTap: () {
                  sheetContext.navigator.pop();
                  search([...queryTags, tag]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(sheetContext.t.actionTag.copy),
                onTap: () {
                  sheetContext.navigator.pop();
                  clip(context, tag);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(sheetContext.t.actionTag.block),
                onTap: () {
                  sheetContext.navigator.pop();
                  block([tag]);
                },
              ),
            ],
          ),
        ),
      );
    }

    final sections = post.hasCategorizedTags
        ? [
            (context.t.artist, post.tagsArtist, _TagCategory.artist),
            (context.t.character, post.tagsCharacter, _TagCategory.character),
            (context.t.copyright, post.tagsCopyright, _TagCategory.copyright),
            (context.t.general, post.tagsGeneral, _TagCategory.general),
            (context.t.meta, post.tagsMeta, _TagCategory.meta),
          ]
        : [(context.t.tags, post.tags, _TagCategory.general)];

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(context.t.details)),
      body: StyledOverlayRegion(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              context.mediaQuery.padding.bottom + 104,
            ),
            children: [
              _InfoHeader(post: post),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    if (post.postUrl.contains(post.id.toString()))
                      ListTile(
                        title: Text(context.t.location),
                        subtitle: _LinkSubtitle(post.postUrl),
                        trailing: _CopyButton(post.postUrl),
                      ),
                    if (post.source.isNotEmpty)
                      ListTile(
                        title: Text(context.t.source),
                        subtitle: _LinkSubtitle(post.source),
                        trailing: _CopyButton(post.source),
                      ),
                    if (post.sampleFile.isNotEmpty)
                      ListTile(
                        title: Text(context.t.fileSample),
                        subtitle: FutureBuilder<PixelSize>(
                          future:
                              post.content.isPhoto && !post.sampleSize.hasPixels
                              ? ExtendedNetworkImageProvider(
                                  post.sampleFile,
                                  cache: true,
                                  headers: headers,
                                ).resolvePixelSize()
                              : Future.value(post.sampleSize),
                          builder: (context, snapshot) {
                            final size = snapshot.data ?? post.sampleSize;
                            return _LinkSubtitle(
                              post.sampleFile,
                              label: '$size, ${post.sampleFile.fileExt}',
                            );
                          },
                        ),
                        trailing: _CopyButton(post.sampleFile),
                      ),
                    ListTile(
                      title: Text(context.t.fileOg),
                      subtitle: _LinkSubtitle(
                        post.originalFile,
                        label:
                            '${post.originalSize}, ${post.originalFile.fileExt}',
                      ),
                      trailing: _CopyButton(post.originalFile),
                    ),
                  ],
                ),
              ),
              for (final (label, tags, category) in sections)
                if (tags.isNotEmpty)
                  _TagsView(
                    label: label,
                    tags: tags,
                    category: category,
                    selected: selected.value,
                    inQuery: queryTags,
                    onTap: toggle,
                    onLongPress: showTagActions,
                  ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _TagSelectionBar(
        selected: selected.value,
        onClear: () => selected.value = [],
        onSearch: () => search(selected.value),
        onAppend: () => search([...queryTags, ...selected.value]),
        onCopy: () => clip(context, selected.value.join(' ')),
        onBlock: () => block(selected.value),
      ),
    );
  }
}

class _InfoHeader extends StatelessWidget {
  const _InfoHeader({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final rating = post.rating;
    final ratingLabel = rating.describe(context);
    final ratingColor = switch (rating) {
      BooruRating.safe => Colors.green,
      BooruRating.sensitive => Colors.amber,
      BooruRating.questionable => Colors.orange,
      BooruRating.explicit => Colors.red,
      BooruRating.all => cs.outline,
    };

    Widget pill(IconData icon, String text, {Color? color}) {
      final tint = color ?? cs.secondary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 6),
            Text(text, style: context.theme.textTheme.labelLarge),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (ratingLabel.isNotEmpty)
          pill(Icons.shield_outlined, ratingLabel, color: ratingColor),
        pill(Icons.arrow_upward_rounded, '${post.score}'),
        if (post.originalSize.hasPixels)
          pill(Icons.aspect_ratio_rounded, '${post.originalSize}'),
        pill(Icons.tag_rounded, '${post.allTags.length}'),
      ],
    );
  }
}

/// Floating glass toolbar that slides in while tags are selected.
class _TagSelectionBar extends StatelessWidget {
  const _TagSelectionBar({
    required this.selected,
    required this.onClear,
    required this.onSearch,
    required this.onAppend,
    required this.onCopy,
    required this.onBlock,
  });

  final List<String> selected;
  final VoidCallback onClear;
  final VoidCallback onSearch;
  final VoidCallback onAppend;
  final VoidCallback onCopy;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final visible = selected.isNotEmpty;
    final cs = context.colorScheme;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.2),
        duration: const Duration(milliseconds: 320),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Glass(
              borderRadius: const BorderRadius.all(Radius.circular(22)),
              color: cs.surfaceContainerHigh,
              border: Border.all(color: cs.outlineVariant),
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).clearButtonTooltip,
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: Text(
                        '${selected.length}',
                        key: ValueKey(selected.length),
                        style: context.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t.actionTag.copy,
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded),
                  ),
                  IconButton(
                    tooltip: context.t.actionTag.block,
                    onPressed: onBlock,
                    icon: const Icon(Icons.block_rounded),
                  ),
                  IconButton(
                    tooltip: context.t.actionTag.append,
                    onPressed: onAppend,
                    icon: const Icon(Icons.playlist_add_rounded),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(context.t.actionTag.search),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _TagCategory {
  artist(Color(0xFFE5534B)),
  character(Color(0xFF3FB950)),
  copyright(Color(0xFFA371F7)),
  general(null),
  meta(Color(0xFFE3A008));

  const _TagCategory(this.color);

  final Color? color;
}

class _TagsView extends StatelessWidget {
  const _TagsView({
    required this.label,
    required this.tags,
    required this.category,
    required this.selected,
    required this.inQuery,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final List<String> tags;
  final _TagCategory category;
  final List<String> selected;
  final Set<String> inQuery;
  final void Function(String tag) onTap;
  final void Function(String tag) onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final accent = category.color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${tags.length}',
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                _TagChip(
                  tag: tag,
                  accent: category.color,
                  selected: selected.contains(tag),
                  inQuery: inQuery.contains(tag),
                  onTap: () => onTap(tag),
                  onLongPress: () => onLongPress(tag),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.accent,
    required this.selected,
    required this.inQuery,
    required this.onTap,
    required this.onLongPress,
  });

  final String tag;
  final Color? accent;
  final bool selected;
  final bool inQuery;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final base = accent ?? cs.onSurface;
    final fg = selected ? cs.onPrimary : base;
    final bg = selected ? cs.primary : base.withValues(alpha: 0.08);
    const radius = BorderRadius.all(Radius.circular(10));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(
          color: inQuery && !selected ? base.withValues(alpha: 0.6) : bg,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.check_rounded, size: 14, color: fg),
                        )
                      : const SizedBox.shrink(),
                ),
                Text(
                  tag.replaceAll('_', ' '),
                  style: context.theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkSubtitle extends StatelessWidget {
  const _LinkSubtitle(this.url, {this.label});

  final String url;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final labelText = label;
    return InkWell(
      onTap: () => launchUrlString(url, mode: LaunchMode.externalApplication),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (labelText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(labelText),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget with ClipboardMixins {
  const _CopyButton(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 18,
      onPressed: () {
        clip(context, text);
      },
      icon: const Icon(Icons.copy_rounded),
    );
  }
}

mixin ClipboardMixins {
  void clip(BuildContext context, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    context.scaffoldMessenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.t.copySuccess),
          duration: const Duration(seconds: 1),
        ),
      );
  }
}
