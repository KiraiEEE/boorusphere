import 'dart:io';

import 'package:flutter/material.dart';

enum SlidePageType { open, close, both }

class SlidePageRoute<T> extends PageRoute<T> {
  SlidePageRoute({
    required this.builder,
    super.settings,
    this.duration = const Duration(milliseconds: 380),
    this.reverseDuration = const Duration(milliseconds: 300),
    this.barrierColor = Colors.transparent,
    this.barrierLabel,
    this.maintainState = true,
    this.type = SlidePageType.both,
    this.opaque = true,
  });

  final Duration duration;
  final Duration reverseDuration;

  final SlidePageType type;

  final Widget Function(BuildContext context) builder;

  @override
  final Color? barrierColor;

  @override
  final String? barrierLabel;

  @override
  final bool maintainState;

  @override
  final bool opaque;

  /// Regular pages on Android use the system's Android 16 transition with
  /// predictive back, so the back gesture previews the previous page.
  bool get _useSystemTransition =>
      Platform.isAndroid && type == SlidePageType.both && opaque;

  static const _systemTransition = PredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration =>
      _useSystemTransition ? _systemTransition.transitionDuration : duration;

  @override
  Duration get reverseTransitionDuration => _useSystemTransition
      ? _systemTransition.reverseTransitionDuration
      : reverseDuration;

  static final _slideIn = Tween(begin: const Offset(0.08, 0), end: Offset.zero);
  static final _slideOut = Tween(
    begin: Offset.zero,
    end: const Offset(-0.06, 0),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_useSystemTransition) {
      return _systemTransition.buildTransitions(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // Material 3 "emphasized" motion: quick start, long gentle settle
    final next = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    final prev = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );

    final fade = FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
        reverseCurve: const Interval(0.2, 1, curve: Curves.easeIn),
      ),
      child: child,
    );

    Widget open(Widget child) {
      return SlideTransition(position: _slideIn.animate(next), child: child);
    }

    Widget close(Widget child) {
      return SlideTransition(position: _slideOut.animate(prev), child: child);
    }

    return switch (type) {
      SlidePageType.open => open(fade),
      SlidePageType.close => close(fade),
      SlidePageType.both => open(close(fade)),
    };
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Glass surfaces of a page share one backdrop read, but never with
    // surfaces of other routes stacked below.
    return BackdropGroup(child: builder(context));
  }
}
