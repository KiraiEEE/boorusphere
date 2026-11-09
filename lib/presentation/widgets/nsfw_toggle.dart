import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Turn NSFW content on or off. Enabling it the first time asks for an age
/// confirmation; returns the resulting state.
Future<bool> setNsfwEnabled(
  BuildContext context,
  WidgetRef ref,
  bool enable,
) async {
  final notifier = ref.read(contentSettingStateProvider.notifier);
  final confirmed = ref.read(contentSettingStateProvider).nsfwConfirmed;
  if (enable && !confirmed) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.eighteen_up_rating_outlined),
        title: Text(context.t.nsfw.confirmTitle),
        content: Text(context.t.nsfw.confirmDesc),
        actions: [
          TextButton(
            onPressed: () => context.navigator.pop(false),
            child: Text(context.t.cancel),
          ),
          FilledButton(
            onPressed: () => context.navigator.pop(true),
            child: Text(context.t.nsfw.confirm),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
  }

  await HapticFeedback.lightImpact();
  await notifier.setNsfw(enable);
  return enable;
}

/// Prominent switch card for toggling NSFW content.
class NsfwSwitchCard extends ConsumerWidget {
  const NsfwSwitchCard({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nsfw = ref.watch(contentSettingStateProvider.select((it) => it.nsfw));
    final cs = context.colorScheme;
    final accent = nsfw ? cs.error : cs.primary;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: nsfw ? 0.12 : 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            onTap: () => setNsfwEnabled(context, ref, !nsfw),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      nsfw
                          ? Icons.local_fire_department_rounded
                          : Icons.shield_rounded,
                      key: ValueKey(nsfw),
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.t.nsfw.title,
                          style: context.theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            nsfw ? context.t.nsfw.on : context.t.nsfw.off,
                            key: ValueKey(nsfw),
                            style: context.theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: nsfw,
                    onChanged: (value) => setNsfwEnabled(context, ref, value),
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
