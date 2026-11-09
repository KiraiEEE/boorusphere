import 'dart:io';

import 'package:boorusphere/pigeon/storage_util.pi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Access to user-visible storage, abstracted per platform.
abstract interface class PlatformStorage {
  factory PlatformStorage() =>
      Platform.isAndroid ? _AndroidStorage() : _DesktopStorage();

  Future<String> downloadPath();
  Future<void> open(String filePath);
  Future<void> scanMedia(String path);
}

class _AndroidStorage implements PlatformStorage {
  final _util = StorageUtil();

  @override
  Future<String> downloadPath() => _util.getDownloadPath();

  @override
  Future<void> open(String filePath) => _util.open(filePath);

  @override
  Future<void> scanMedia(String path) => _util.scanMedia(path);
}

class _DesktopStorage implements PlatformStorage {
  @override
  Future<String> downloadPath() async {
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    return dir.path;
  }

  @override
  Future<void> open(String filePath) async {
    await launchUrl(Uri.file(filePath));
  }

  // Desktop file managers index files on their own
  @override
  Future<void> scanMedia(String path) async {}
}
