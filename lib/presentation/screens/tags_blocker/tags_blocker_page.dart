import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/data/repository/tags_blocker/blacklist.dart';
import 'package:boorusphere/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/presentation/provider/settings/server_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/provider/tags_blocker_state.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/widgets/glass.dart';
import 'package:boorusphere/presentation/widgets/notice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

@RoutePage()
class TagsBlockerPage extends HookConsumerWidget {
  const TagsBlockerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(tagsBlockerStateProvider);
    final servers = ref.watch(serverStateProvider);
    final lastServerId = ref.watch(
      serverSettingStateProvider.select((it) => it.lastActiveId),
    );
    final imeIncognito = ref.watch(
      uiSettingStateProvider.select((it) => it.imeIncognito),
    );
    final input = useTextEditingController();
    final filter = useState('');
    final scope = useState(''); // '' = all servers
    useListenable(input);

    final preview = Blacklist.splitInput(input.text);
    final currentServer = servers.getById(lastServerId);

    void submit() {
      if (preview.isEmpty) return;
      HapticFeedback.lightImpact();
      ref
          .read(tagsBlockerStateProvider.notifier)
          .pushAll(serverId: scope.value, tags: preview);
      input.clear();
    }

    void remove(int key, BooruTag tag) {
      ref.read(tagsBlockerStateProvider.notifier).delete(key);
      context.scaffoldMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.t.tagsBlocker.removed(rule: tag.name)),
            action: SnackBarAction(
              label: context.t.tagsBlocker.undo,
              onPressed: () =>
                  ref.read(tagsBlockerStateProvider.notifier).restore([tag]),
            ),
          ),
        );
    }

    final query = filter.value.trim().toLowerCase();
    final entries = rules.entries
        .where((it) => query.isEmpty || it.value.name.contains(query))
        .toList()
        .reversed
        .toList();

    String scopeLabel(String serverId) => serverId.isEmpty
        ? context.t.tagsBlocker.scopeAll
        : context.t.tagsBlocker.scopeServer(
            serverName: servers
                .getById(serverId, or: Server(id: serverId))
                .name,
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(context.t.tagsBlocker.title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          context.mediaQuery.padding.top + kToolbarHeight + 12,
          16,
          context.mediaQuery.padding.bottom + 24,
        ),
        children: [
          Text(
            context.t.tagsBlocker.desc,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: input,
            minLines: 1,
            maxLines: 4,
            enableIMEPersonalizedLearning: !imeIncognito,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(
              hintText: context.t.tagsBlocker.hint,
              prefixIcon: const Icon(Icons.block_rounded),
              suffixIcon: IconButton(
                onPressed: preview.isEmpty ? null : submit,
                icon: const Icon(Icons.add_rounded),
                tooltip: context.t.tagsBlocker.add,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: '',
                label: Text(context.t.tagsBlocker.scopeAll),
                icon: const Icon(Icons.public_rounded),
              ),
              if (currentServer != Server.empty && !currentServer.isAll)
                ButtonSegment(
                  value: currentServer.id,
                  label: Text(
                    currentServer.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: const Icon(Icons.dns_rounded),
                ),
            ],
            selected: {scope.value},
            onSelectionChanged: (it) => scope.value = it.first,
            showSelectedIcon: false,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: preview.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          context.t.tagsBlocker.preview,
                          style: context.theme.textTheme.labelMedium,
                        ),
                        for (final rule in preview)
                          Chip(
                            label: Text(rule),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          const _SyntaxHelp(),
          const SizedBox(height: 16),
          if (rules.length > 6)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                onChanged: (it) => filter.value = it,
                decoration: InputDecoration(
                  hintText: context.t.tagsBlocker.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
          if (rules.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                context.t.tagsBlocker.count(n: rules.length),
                style: context.theme.textTheme.labelLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (rules.isEmpty)
            NoticeCard(
              icon: const Icon(Icons.done_all_rounded),
              margin: const EdgeInsets.only(top: 24),
              children: Text(context.t.tagsBlocker.empty),
            ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Dismissible(
                key: ValueKey(entry.key),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => remove(entry.key, entry.value),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: context.colorScheme.errorContainer,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colorScheme.onErrorContainer,
                  ),
                ),
                child: Card(
                  child: ListTile(
                    title: Text(entry.value.name),
                    subtitle: Text(scopeLabel(entry.value.serverId)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => remove(entry.key, entry.value),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SyntaxHelp extends StatelessWidget {
  const _SyntaxHelp();

  @override
  Widget build(BuildContext context) {
    final s = context.t.tagsBlocker.syntax;
    final rows = [
      ('tag', s.tag),
      ('tag*', s.wildcard),
      ('tag1 tag2', s.combo),
      ('tag -other', s.exclude),
      ('rating:e', s.rating),
      ('score:<0', s.score),
    ];
    return Card(
      child: Theme(
        data: context.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: Text(context.t.tagsBlocker.syntaxTitle),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            for (final (code, desc) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        code,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(child: Text(desc)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
