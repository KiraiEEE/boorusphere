import 'dart:io';

/// Platform helpers, kept as getters so tests can run on any host.
bool get isAndroid => Platform.isAndroid;

bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

bool get isMobile => Platform.isAndroid || Platform.isIOS;
