import 'dart:io';

import 'package:boorusphere/data/repository/storage/platform_storage.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shared_storage_handle.g.dart';

@Riverpod(keepAlive: true)
SharedStorageHandle sharedStorageHandle(Ref ref) {
  throw UnimplementedError();
}

Future<SharedStorageHandle> provideSharedStorageHandle() async {
  final storage = PlatformStorage();
  final downloadPath = await storage.downloadPath();
  return SharedStorageHandle(downloadPath: downloadPath, storage: storage);
}

class SharedStorageHandle {
  SharedStorageHandle({required this.downloadPath, required this.storage});

  final String downloadPath;
  final PlatformStorage storage;

  String get path {
    return p.join(downloadPath, 'Boorusphere');
  }

  File get _nomedia {
    return File(p.join(path, '.nomedia'));
  }

  /// `.nomedia` only means something to Android's media scanner
  bool get canHide => Platform.isAndroid;

  bool get isHidden {
    return canHide && _nomedia.existsSync();
  }

  Future<void> init() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
    final dir = Directory(path);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
        // ignore: empty_catches
      } catch (e) {}
    }
  }

  Directory createSubDir(String directory) {
    final dir = Directory(p.join(path, directory));
    try {
      dir.createSync(recursive: true);
      // ignore: empty_catches
    } catch (e) {}
    return dir;
  }

  bool fileExists(String relativePath) {
    final file = File(p.join(path, Uri.decodeFull(relativePath)));
    try {
      return file.existsSync();
      // ignore: empty_catches
    } catch (e) {}
    return false;
  }

  /// Index a single downloaded file so it shows up in the gallery
  Future<void> rescanFile(String relativePath) async {
    try {
      await storage.scanMedia(p.join(path, Uri.decodeFull(relativePath)));
      // ignore: empty_catches
    } catch (e) {}
  }

  /// [fileName] if it's free in the download folder, otherwise
  /// `name (1).ext`, `name (2).ext`, ... so nothing gets overwritten
  String availableName(String fileName) {
    if (!fileExists(fileName)) return fileName;
    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    for (var i = 1; ; i++) {
      final candidate = '$base ($i)$ext';
      if (!fileExists(candidate)) return candidate;
    }
  }

  Future<void> rescan() async {
    try {
      await storage.scanMedia(path);
      // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> hide(bool hide) async {
    if (!canHide) return;
    await init();
    final isExists = _nomedia.existsSync();
    try {
      if (hide && !isExists) {
        await _nomedia.create();
      } else if (!hide && isExists) {
        await _nomedia.delete();
      }
      // ignore: empty_catches
    } catch (e) {}
    await rescan();
  }

  Future<void> open(String dest, {String? on}) async {
    try {
      final filePath = p.join(on ?? path, Uri.decodeFull(dest));
      await storage.open(filePath);
      // ignore: empty_catches
    } catch (e) {}
  }
}
