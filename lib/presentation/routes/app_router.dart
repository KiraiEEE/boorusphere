import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/presentation/routes/app_router.gr.dart';
import 'package:boorusphere/presentation/routes/slide_page_route.dart';
import 'package:flutter/widgets.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  static Route<T> _routeBuilder<T>(
    BuildContext context,
    Widget child,
    AutoRoutePage<T> page,
  ) {
    return SlidePageRoute<T>(settings: page, builder: (context) => child);
  }

  static Route<T> _homeRouteBuilder<T>(
    BuildContext context,
    Widget child,
    AutoRoutePage<T> page,
  ) {
    return SlidePageRoute<T>(
      settings: page,
      builder: (context) => child,
      type: SlidePageType.close,
    );
  }

  @override
  late final List<AutoRoute> routes = [
    AutoRoute(page: InitialDirectorRoute.page, path: '/'),
    CustomRoute(page: HomeRoute.page, customRouteBuilder: _homeRouteBuilder),
    CustomRoute(page: PostDetailsRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(page: DownloadsRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(
      page: ServerEditorRoute.page,
      customRouteBuilder: _routeBuilder,
    ),
    CustomRoute(page: ServerRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(
      page: ServerPresetRoute.page,
      customRouteBuilder: _routeBuilder,
    ),
    CustomRoute(page: TagsBlockerRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(page: SettingsRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(
      page: LanguageSettingsRoute.page,
      customRouteBuilder: _routeBuilder,
    ),
    CustomRoute(page: DataBackupRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(page: AboutRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(page: ChangelogRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(page: LicensesRoute.page, customRouteBuilder: _routeBuilder),
    CustomRoute(page: FavoritesRoute.page, customRouteBuilder: _routeBuilder),
  ];
}
