import 'dart:io';

import 'package:boorusphere/constant/app.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/downloads/entity/download_progress.dart';
import 'package:boorusphere/data/repository/version/app_version_repo.dart';
import 'package:boorusphere/data/repository/version/entity/app_version.dart';
import 'package:boorusphere/presentation/provider/download/download_backend.dart';
import 'package:boorusphere/presentation/provider/download/download_state.dart';
import 'package:boorusphere/presentation/provider/download/downloader.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'app_updater.g.dart';

@riverpod
AppUpdater appUpdater(Ref ref) {
  return AppUpdater(ref);
}

@riverpod
DownloadProgress appUpdateProgress(Ref ref) {
  final id = ref.watch(appUpdaterProvider.select((it) => it.id));
  return ref.watch(downloadProgressStateProvider).getById(id);
}

class AppUpdater {
  AppUpdater(this.ref);

  final Ref ref;

  String id = '';

  /// Only Android can download and install updates in-app, other platforms
  /// are sent to the release page.
  bool get canSelfUpdate => Platform.isAndroid;

  String _fileNameOf(AppVersion version) {
    return 'boorusphere-$version-$kAppArch.apk';
  }

  Future<void> clear() async {
    final ids =
        await ref.read(downloadBackendProvider).removeBySuffix('.apk');
    for (final taskId in ids) {
      await ref.read(downloadEntryStateProvider.notifier).remove(taskId);
    }
    id = '';
  }

  Future<void> start(AppVersion version) async {
    if (!canSelfUpdate) {
      await launchUrl(
        Uri.parse('${AppVersionRepo.gitUrl}/releases/tag/$version'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    await clear();
    final fileName = _fileNameOf(version);
    final url = '${AppVersionRepo.gitUrl}/releases/download/$version/$fileName';
    final newId =
        await ref.read(downloaderProvider).download(Post.appReserved, url: url);

    if (newId != null) {
      id = newId;
    }
  }

  Future<void> install(AppVersion version) async {
    ref.read(downloaderProvider).openFile(id: id);
  }
}
