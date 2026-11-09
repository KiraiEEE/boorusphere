import 'dart:io';

import 'package:boorusphere/data/repository/version/entity/app_version.dart';
import 'package:boorusphere/domain/repository/env_repo.dart';
import 'package:boorusphere/pigeon/app_env.pi.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CurrentEnvRepo implements EnvRepo {
  CurrentEnvRepo({required this.env});

  static Future<CurrentEnvRepo> create() async {
    if (Platform.isAndroid) {
      return CurrentEnvRepo(env: await AppEnv().get());
    }

    final info = await PackageInfo.fromPlatform();
    return CurrentEnvRepo(
      env: Env(
        versionName: info.version,
        versionCode: int.tryParse(info.buildNumber) ?? 0,
        sdkVersion: 0,
      ),
    );
  }

  @override
  final Env env;

  @override
  int get sdkVersion => env.sdkVersion;

  @override
  AppVersion get appVersion => AppVersion.fromString(env.versionName);
}
