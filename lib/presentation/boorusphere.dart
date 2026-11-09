import 'dart:io';

import 'package:boorusphere/data/provider.dart';
import 'package:boorusphere/domain/provider.dart';
import 'package:boorusphere/presentation/i18n/helper.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/app_updater.dart';
import 'package:boorusphere/presentation/provider/download/download_backend.dart';
import 'package:boorusphere/presentation/provider/download/download_state.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/provider/shared_storage_handle.dart';
import 'package:boorusphere/presentation/routes/app_route_observer.dart';
import 'package:boorusphere/presentation/routes/app_router.dart';
import 'package:boorusphere/presentation/widgets/app_theme_builder.dart';
import 'package:boorusphere/utils/http/overrides.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Lets mouse and trackpad drag pageviews and lists on desktop, like touch.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class Boorusphere extends HookConsumerWidget {
  const Boorusphere({super.key});

  Future<void> initializeAsyncStates(
    WidgetRef ref,
    Function onCompleted,
  ) async {
    await ref.read(serverStateProvider.notifier).populate();

    final envRepo = ref.read(envRepoProvider);
    final appStateRepo = ref.read(appStateRepoProvider);
    if (envRepo.appVersion.isNewerThan(appStateRepo.version)) {
      await ref.read(appUpdaterProvider).clear();
    }

    onCompleted();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(uiSettingStateProvider.select((ui) => ui.locale));
    final theme = ref.watch(
      uiSettingStateProvider.select((ui) => ui.themeMode),
    );
    final isMidnight = ref.watch(
      uiSettingStateProvider.select((ui) => ui.midnightMode),
    );
    final cookieJar = ref.watch(cookieJarProvider);
    final router = useMemoized(AppRouter.new);
    final initialized = useState(false);

    useEffect(() {
      initializeAsyncStates(ref, () {
        initialized.value = true;
      });
      return null;
    }, []);

    useEffect(() {
      HttpOverrides.global = CustomHttpOverrides(cookieJar: cookieJar);
      return () {
        HttpOverrides.global = null;
      };
    }, [cookieJar]);

    useEffect(() {
      LocaleHelper.update(locale);
      return null;
    }, [locale]);

    useEffect(() {
      final sub = ref.read(downloadBackendProvider).progress.listen((
        progress,
      ) async {
        if (progress.status.isDownloaded) {
          await ref.read(sharedStorageHandleProvider).rescan();
        }
        await ref.read(downloadProgressStateProvider.notifier).update(progress);
      });
      return sub.cancel;
    }, []);

    useEffect(() {
      if (Platform.isAndroid) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      return null;
    }, []);

    if (!initialized.value) {
      return const SizedBox.shrink();
    }

    return AppThemeBuilder(
      builder: (context, appTheme) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Boorusphere',
        theme: appTheme.day,
        darkTheme: isMidnight ? appTheme.midnight : appTheme.night,
        themeMode: theme,
        themeAnimationDuration: const Duration(milliseconds: 350),
        themeAnimationCurve: Curves.easeOutCubic,
        scrollBehavior: const _AppScrollBehavior(),
        routerConfig: router.config(
          navigatorObservers: () => [AppRouteObserver(ref)],
        ),
        locale: TranslationProvider.of(context).locale.digestedFlutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }
}

// Convert slang locale to flutter locale
extension on AppLocale {
  Locale get digestedFlutterLocale {
    if (this == AppLocale.uwu) {
      return AppLocale.en.flutterLocale;
    }

    // Return the actual locale
    return flutterLocale;
  }
}
