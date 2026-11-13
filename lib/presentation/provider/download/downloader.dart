import 'package:boorusphere/data/dio/headers_factory.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/downloads/entity/download_entry.dart';
import 'package:boorusphere/data/repository/downloads/entity/download_progress.dart';
import 'package:boorusphere/domain/provider.dart';
import 'package:boorusphere/presentation/provider/booru/post_headers_factory.dart';
import 'package:boorusphere/presentation/provider/download/download_backend.dart';
import 'package:boorusphere/presentation/provider/download/download_state.dart';
import 'package:boorusphere/presentation/provider/shared_storage_handle.dart';
import 'package:boorusphere/utils/extensions/string.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloader.g.dart';

// kept alive: downloads outlive the dialog that started them
@Riverpod(keepAlive: true)
Downloader downloader(Ref ref) {
  return Downloader(ref);
}

class Downloader {
  Downloader(this.ref);

  final Ref ref;
  var _scannedOnLaunch = false;

  DownloadBackend get _backend => ref.read(downloadBackendProvider);

  Map<String, String> _headersOf(String url) {
    final versionRepo = ref.read(versionRepoProvider);
    return HeadersFactory.builder()
        .setUserAgent(versionRepo.current)
        .setReferer(createReferer(url))
        .build();
  }

  static String _sanitize(String url) {
    // sanitize forbidden characters on the file name
    return Uri.decodeComponent(
      url.fileName,
    ).replaceAll(RegExp(r'([^a-zA-Z0-9\s\.\(\)_]+)'), '_');
  }

  Future<String?> download(
    Post post, {
    String? url,
    String Function(String fileName)? dest,
  }) async {
    final fileUrl = url ?? post.originalFile;
    final sharedStorageHandle = ref.read(sharedStorageHandleProvider);

    await sharedStorageHandle.init();
    // Android's download worker refuses to write over an existing file and the
    // task silently fails, so saving the same post twice needs a fresh name.
    final fileName = sharedStorageHandle.availableName(_sanitize(fileUrl));
    final taskId = await _backend.enqueue(
      url: fileUrl,
      fileName: fileName,
      savedDir: sharedStorageHandle.path,
      headers: _headersOf(fileUrl),
    );

    if (taskId != null) {
      final entry = DownloadEntry(
        id: taskId,
        post: post,
        dest: dest?.call(fileName) ?? fileName,
      );
      await ref.read(downloadEntryStateProvider.notifier).add(entry);
    }
    return taskId;
  }

  /// Apply an update from the download engine and index finished files.
  Future<void> onProgress(DownloadProgress progress) async {
    final known = ref.read(downloadProgressStateProvider).getById(progress.id);
    await ref.read(downloadProgressStateProvider.notifier).update(progress);
    if (!progress.status.isDownloaded || known.status.isDownloaded) return;

    final entry = ref.read(downloadEntryStateProvider).getById(progress.id);
    if (entry == DownloadEntry.empty) return;
    // the engine reports completion right before it closes the file
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await ref.read(sharedStorageHandleProvider).rescanFile(entry.dest);
  }

  /// Pick up whatever finished or failed while the app wasn't running,
  /// so entries don't stay stuck on "downloading".
  Future<void> sync() async {
    if (!_scannedOnLaunch) {
      // once per launch, index anything an earlier session left out of the
      // gallery (already indexed files are skipped by the media scanner)
      _scannedOnLaunch = true;
      await ref.read(sharedStorageHandleProvider).rescan();
    }
    final List<DownloadProgress> tasks;
    try {
      tasks = await _backend.snapshot();
    } catch (e) {
      return;
    }
    final entries = ref.read(downloadEntryStateProvider);
    final progresses = ref.read(downloadProgressStateProvider);
    for (final task in tasks) {
      if (entries.getById(task.id) == DownloadEntry.empty) continue;
      final known = progresses.getById(task.id);
      if (known.status == task.status && known.progress == task.progress) {
        continue;
      }
      await onProgress(
        known.timestamp > 0 ? task.copyWith(timestamp: known.timestamp) : task,
      );
    }
  }

  Future<void> retry({required String id}) async {
    final entry = ref.read(downloadEntryStateProvider).getById(id);
    if (entry == DownloadEntry.empty) return;

    // Start over as a new task instead of the engine's own retry: that one
    // reuses the old file name, which still holds the failed partial file,
    // so it fails again on Android.
    final post = entry.post;
    final base = entry.dest.replaceFirst(RegExp(r' \(\d+\)(?=\.[^.]*$|$)'), '');
    final url = post.sampleFile.isNotEmpty && _sanitize(post.sampleFile) == base
        ? post.sampleFile
        : post.originalFile;
    await _backend.remove(id);
    await ref.read(downloadEntryStateProvider.notifier).remove(id);
    await download(post, url: url);
  }

  Future<void> cancel({required String id}) async {
    await _backend.cancel(id);
  }

  Future<void> clear({required String id}) async {
    await _backend.remove(id);
    await ref.read(downloadEntryStateProvider.notifier).remove(id);
  }

  void openFile({required String id}) {
    final entry = ref.read(downloadEntryStateProvider).getById(id);
    ref.read(sharedStorageHandleProvider).open(entry.dest);
  }
}
