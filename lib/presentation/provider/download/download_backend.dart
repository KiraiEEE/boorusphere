import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:boorusphere/data/repository/downloads/entity/download_progress.dart';
import 'package:boorusphere/data/repository/downloads/entity/download_status.dart';
import 'package:boorusphere/presentation/utils/extensions/flutter_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_backend.g.dart';

@Riverpod(keepAlive: true)
DownloadBackend downloadBackend(Ref ref) {
  final backend = Platform.isAndroid
      ? AndroidDownloadBackend()
      : DioDownloadBackend();
  ref.onDispose(backend.dispose);
  return backend;
}

/// Platform specific download engine.
abstract class DownloadBackend {
  Stream<DownloadProgress> get progress;

  Future<String?> enqueue({
    required String url,
    required String fileName,
    required String savedDir,
    Map<String, String> headers = const {},
  });

  Future<String?> retry(String id);

  Future<void> cancel(String id);

  Future<void> remove(String id, {bool deleteContent = false});

  /// Remove every task whose file name ends with [suffix]
  Future<List<String>> removeBySuffix(String suffix);

  Future<void> removeAll();

  void dispose();
}

/// Background downloads with system notifications via flutter_downloader.
class AndroidDownloadBackend extends DownloadBackend {
  AndroidDownloadBackend() {
    _unregister();
    IsolateNameServer.registerPortWithName(_receiver.sendPort, _portName);
    FlutterDownloader.registerCallback(_onProgressUpdated);
    _receiver.listen((data) {
      final status = DownloadTaskStatus.fromInt(data[1]);
      _controller.add(
        DownloadProgress(
          id: data[0],
          status: status.toDownloadStatus(),
          progress: data[2],
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  final _receiver = ReceivePort();
  final _controller = StreamController<DownloadProgress>.broadcast();

  @override
  Stream<DownloadProgress> get progress => _controller.stream;

  @override
  Future<String?> enqueue({
    required String url,
    required String fileName,
    required String savedDir,
    Map<String, String> headers = const {},
  }) {
    return FlutterDownloader.enqueue(
      url: url,
      fileName: fileName,
      savedDir: savedDir,
      showNotification: true,
      openFileFromNotification: true,
      headers: headers,
    );
  }

  @override
  Future<String?> retry(String id) => FlutterDownloader.retry(taskId: id);

  @override
  Future<void> cancel(String id) => FlutterDownloader.cancel(taskId: id);

  @override
  Future<void> remove(String id, {bool deleteContent = false}) {
    return FlutterDownloader.remove(
      taskId: id,
      shouldDeleteContent: deleteContent,
    );
  }

  @override
  Future<List<String>> removeBySuffix(String suffix) async {
    final tasks = await FlutterDownloader.loadTasks() ?? <DownloadTask>[];
    final ids = <String>[];
    for (final task in tasks) {
      if (task.filename?.endsWith(suffix) != true) continue;
      await remove(task.taskId, deleteContent: true);
      ids.add(task.taskId);
    }
    return ids;
  }

  @override
  Future<void> removeAll() async {
    final tasks = await FlutterDownloader.loadTasks() ?? <DownloadTask>[];
    await Future.wait(tasks.map((it) => remove(it.taskId)));
  }

  void _unregister() {
    if (IsolateNameServer.lookupPortByName(_portName) != null) {
      IsolateNameServer.removePortNameMapping(_portName);
    }
  }

  @override
  void dispose() {
    _unregister();
    _receiver.close();
    _controller.close();
  }

  static const _portName = 'DownloaderHandle';

  @pragma('vm:entry-point')
  static void _onProgressUpdated(String id, int status, int progress) {
    IsolateNameServer.lookupPortByName(_portName)?.send([id, status, progress]);
  }
}

class _DioTask {
  _DioTask(this.url, this.path, this.headers);

  final String url;
  final String path;
  final Map<String, String> headers;
  final token = CancelToken();
}

/// In-process downloader used on desktop where no download service exists.
class DioDownloadBackend extends DownloadBackend {
  DioDownloadBackend([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;
  final _tasks = <String, _DioTask>{};
  final _controller = StreamController<DownloadProgress>.broadcast();
  final _random = Random();

  @override
  Stream<DownloadProgress> get progress => _controller.stream;

  void _emit(String id, DownloadStatus status, int progress) {
    if (_controller.isClosed) return;
    _controller.add(
      DownloadProgress(
        id: id,
        status: status,
        progress: progress,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String _newId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$time-$salt';
  }

  Future<void> _run(String id, _DioTask task) async {
    var lastPercent = 0;
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    final partial = File('${task.path}.part');
    _emit(id, DownloadStatus.pending, 0);
    try {
      await _dio.download(
        task.url,
        partial.path,
        cancelToken: task.token,
        options: Options(headers: task.headers),
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final percent = (received * 100 ~/ total).clamp(0, 100);
          final now = DateTime.now();
          // throttle UI updates to keep lists smooth
          if (percent == lastPercent ||
              (percent < 100 &&
                  now.difference(lastEmit).inMilliseconds < 120)) {
            return;
          }
          lastPercent = percent;
          lastEmit = now;
          _emit(id, DownloadStatus.downloading, percent);
        },
      );
      final target = File(task.path);
      if (target.existsSync()) target.deleteSync();
      await partial.rename(task.path);
      _emit(id, DownloadStatus.downloaded, 100);
    } catch (e) {
      if (partial.existsSync()) partial.deleteSync();
      final canceled = e is DioException && CancelToken.isCancel(e);
      _emit(
        id,
        canceled ? DownloadStatus.canceled : DownloadStatus.failed,
        lastPercent,
      );
    }
  }

  String _start(_DioTask task) {
    final id = _newId();
    _tasks[id] = task;
    unawaited(_run(id, task));
    return id;
  }

  @override
  Future<String?> enqueue({
    required String url,
    required String fileName,
    required String savedDir,
    Map<String, String> headers = const {},
  }) async {
    return _start(_DioTask(url, p.join(savedDir, fileName), headers));
  }

  @override
  Future<String?> retry(String id) async {
    final old = _tasks.remove(id);
    if (old == null) return null;
    return _start(_DioTask(old.url, old.path, old.headers));
  }

  @override
  Future<void> cancel(String id) async {
    _tasks[id]?.token.cancel();
  }

  @override
  Future<void> remove(String id, {bool deleteContent = false}) async {
    final task = _tasks.remove(id);
    if (task == null) return;
    task.token.cancel();
    if (deleteContent) {
      final file = File(task.path);
      if (file.existsSync()) file.deleteSync();
    }
  }

  @override
  Future<List<String>> removeBySuffix(String suffix) async {
    final ids = [
      for (final it in _tasks.entries)
        if (it.value.path.endsWith(suffix)) it.key,
    ];
    for (final id in ids) {
      await remove(id, deleteContent: true);
    }
    return ids;
  }

  @override
  Future<void> removeAll() async {
    for (final task in _tasks.values) {
      task.token.cancel();
    }
    _tasks.clear();
  }

  @override
  void dispose() {
    removeAll();
    _controller.close();
    _dio.close();
  }
}
