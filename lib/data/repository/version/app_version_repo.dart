import 'package:boorusphere/data/repository/version/entity/app_version.dart';
import 'package:boorusphere/domain/repository/env_repo.dart';
import 'package:boorusphere/domain/repository/version_repo.dart';
import 'package:dio/dio.dart';

class AppVersionRepo implements VersionRepo {
  AppVersionRepo({required this.envRepo, required this.client});

  final EnvRepo envRepo;
  final Dio client;

  @override
  AppVersion get current => envRepo.appVersion;

  /// The newest published GitHub release. Bumping the version on the main
  /// branch alone doesn't count, so the app never offers an update that
  /// has no downloadable APK yet.
  @override
  Future<AppVersion> fetch() async {
    final res = await client.get(
      latestReleaseUrl,
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    final data = res.data;
    if (res.statusCode == 200 && data is Map) {
      return versionOfTag(data['tag_name']);
    }
    return AppVersion.zero;
  }

  /// "2.0.2" or "v2.0.2"; anything else is treated as no release
  static AppVersion versionOfTag(Object? tag) {
    if (tag is! String) return AppVersion.zero;
    final match = RegExp(r'^v?(\d+\.\d+\.\d+)').firstMatch(tag.trim());
    return match == null
        ? AppVersion.zero
        : AppVersion.fromString(match.group(1)!);
  }

  static const gitUrl = 'https://github.com/KiraiEEE/boorusphere';
  static const latestReleaseUrl =
      'https://api.github.com/repos/KiraiEEE/boorusphere/releases/latest';
}
