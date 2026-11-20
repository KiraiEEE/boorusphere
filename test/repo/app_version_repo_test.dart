import 'package:boorusphere/data/repository/version/app_version_repo.dart';
import 'package:boorusphere/data/repository/version/entity/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release tags become versions', () {
    expect(
      AppVersionRepo.versionOfTag('2.0.2'),
      const AppVersion(major: 2, minor: 0, patch: 2),
    );
    expect(
      AppVersionRepo.versionOfTag('v2.1.0'),
      const AppVersion(major: 2, minor: 1, patch: 0),
    );
    expect(AppVersionRepo.versionOfTag('nightly'), AppVersion.zero);
    expect(AppVersionRepo.versionOfTag(null), AppVersion.zero);
  });

  test('only a newer release counts as an update', () {
    const installed = AppVersion(major: 2, minor: 0, patch: 2);
    expect(AppVersionRepo.versionOfTag('2.0.2').isNewerThan(installed), false);
    expect(AppVersionRepo.versionOfTag('2.0.3').isNewerThan(installed), true);
    expect(AppVersionRepo.versionOfTag('1.9.9').isNewerThan(installed), false);
  });
}
