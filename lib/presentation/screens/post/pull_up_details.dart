import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/presentation/screens/home/search_session.dart';
import 'package:boorusphere/presentation/screens/post/post_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// True while the image on screen is zoomed in, so a vertical drag pans the
/// image instead of pulling up the details.
final postZoomed = ValueNotifier<bool>(false);

/// Swipe up anywhere on the post to drag the details page in under the
/// finger. Let go past a third of the screen (or flick) and it settles open,
/// otherwise it slides back down.
class PullUpToDetails extends StatefulWidget {
  const PullUpToDetails({super.key, required this.post, required this.child});

  final Post post;
  final Widget child;

  static void open(BuildContext context, Post post) {
    Navigator.of(context).push(_route(context, post));
  }

  static _PullUpRoute _route(BuildContext context, Post post) {
    final container = ProviderScope.containerOf(context);
    return _PullUpRoute(
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: PostDetailsPage(
          post: post,
          session: container.read(searchSessionProvider),
        ),
      ),
    );
  }

  @override
  State<PullUpToDetails> createState() => _PullUpToDetailsState();
}

class _PullUpToDetailsState extends State<PullUpToDetails> {
  _PullUpRoute? _route;
  bool _ignore = false;
  bool _pastThreshold = false;

  static const _threshold = 0.35;
  static const _flingVelocity = 700.0;

  NavigatorState get _navigator => Navigator.of(context);

  void _onStart(DragStartDetails details) {
    _route = null;
    _ignore = false;
    _pastThreshold = false;
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_ignore) return;
    final dy = details.primaryDelta ?? 0;
    var route = _route;
    if (route == null) {
      // only an upward drag opens the details
      if (dy >= 0) {
        _ignore = true;
        return;
      }
      route = PullUpToDetails._route(context, widget.post);
      _route = route;
      _navigator.push(route);
      _navigator.didStartUserGesture();
      route.drag
        ..stop()
        ..value = 0;
    }

    final height = context.size?.height ?? 1;
    final controller = route.drag;
    controller.value = (controller.value - dy / height).clamp(0.0, 1.0);

    final past = controller.value >= _threshold;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      if (past) HapticFeedback.lightImpact();
    }
  }

  void _onEnd(DragEndDetails details) {
    final route = _route;
    _route = null;
    if (route == null) return;
    final controller = route.drag;
    final velocity = -(details.primaryVelocity ?? 0);
    final open =
        velocity > _flingVelocity ||
        (velocity > -_flingVelocity && controller.value >= _threshold);

    if (open) {
      controller.animateTo(
        1,
        duration: Duration(milliseconds: (320 * (1 - controller.value)).ceil()),
        curve: Curves.easeOutCubic,
      );
    } else {
      // popping animates back down from wherever the finger let go
      if (route.isCurrent) _navigator.pop();
    }
    _navigator.didStopUserGesture();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: postZoomed,
      child: widget.child,
      // same widget either way so the page view below never remounts,
      // without callbacks it simply stays out of the gesture arena
      builder: (context, zoomed, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: zoomed ? null : _onStart,
        onVerticalDragUpdate: zoomed ? null : _onUpdate,
        onVerticalDragEnd: zoomed ? null : _onEnd,
        onVerticalDragCancel: zoomed ? null : () => _onEnd(DragEndDetails()),
        child: child,
      ),
    );
  }
}

class _PullUpRoute extends PageRoute<void> {
  _PullUpRoute({required this.builder});

  final WidgetBuilder builder;

  /// The transition controller, driven directly by the drag
  AnimationController get drag => controller!;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // follow the finger 1:1 while dragging, ease when animating on its own
    final position = navigator?.userGestureInProgress ?? false
        ? animation
        : CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(position),
      child: child,
    );
  }
}
