import 'package:boorusphere/data/dio/headers_factory.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/downloads/entity/download_entry.dart';
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

  DownloadBackend get _backend => ref.read(downloadBackendProvider);

  Map<String, String> _headersOf(String url) {
    final versionRepo = ref.read(versionRepoProvider);
    return HeadersFactory.builder()
        .setUserAgent(versionRepo.current)
        .setReferer(createReferer(url))
        .build();
  }

  Future<String?> download(
    Post post, {
    String? url,
    String Function(String fileName)? dest,
  }) async {
    final fileUrl = url ?? post.originalFile;
    // sanitize forbidden characters on the file name
    final fileName = Uri.decodeComponent(
      fileUrl.fileName,
    ).replaceAll(RegExp(r'([^a-zA-Z0-9\s\.\(\)_]+)'), '_');
    final sharedStorageHandle = ref.read(sharedStorageHandleProvider);

    await sharedStorageHandle.init();
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

  Future<void> retry({required String id}) async {
    final entry = ref.read(downloadEntryStateProvider).getById(id);
    final newId = await _backend.retry(id);
    if (newId != null) {
      await ref
          .read(downloadEntryStateProvider.notifier)
          .update(id, entry.copyWith(id: newId));
      return;
    }

    // The backend lost track of this task (e.g. app restarted on desktop),
    // start it again from the post data.
    if (entry == DownloadEntry.empty) return;
    final post = entry.post;
    final url =
        post.sampleFile.isNotEmpty &&
            Uri.decodeComponent(post.sampleFile.fileName) ==
                Uri.decodeComponent(entry.dest)
        ? post.sampleFile
        : post.originalFile;
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
