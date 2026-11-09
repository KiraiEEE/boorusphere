import 'dart:ui';

import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Frosted glass surface.
///
/// Uses [BackdropFilter.grouped] so every glass surface inside the same
/// route shares a single backdrop read, which keeps blur cheap even with
/// several surfaces on screen. When blur is disabled in settings it falls
/// back to an almost opaque tint so content stays readable.
class Glass extends ConsumerWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.sigma = 20,
    this.color,
    this.opacity,
    this.border,
    this.padding,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final Color? color;
  final double? opacity;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blur = ref.watch(uiSettingStateProvider.select((it) => it.blur));
    final base = color ?? context.theme.scaffoldBackgroundColor;
    final alpha =
        opacity ?? (blur ? (context.isLightThemed ? 0.72 : 0.64) : 0.97);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: base.withValues(alpha: alpha),
        borderRadius: borderRadius,
        border: border,
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    if (blur) {
      content = BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }

    return RepaintBoundary(
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );
  }
}

/// [AppBar] on top of a [Glass] surface. Use together with
/// `Scaffold(extendBodyBehindAppBar: true)` so content scrolls beneath it.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.bottom,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Glass(
      border: Border(
        bottom: BorderSide(color: context.colorScheme.outlineVariant),
      ),
      child: AppBar(
        title: title,
        actions: actions,
        leading: leading,
        bottom: bottom,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
    );
  }
}
