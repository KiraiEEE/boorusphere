import 'dart:convert';

import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/domain/repository/server_data_repo.dart';
import 'package:boorusphere/presentation/provider/data_backup/data_backup.dart';
import 'package:hive_ce/hive_ce.dart';

class UserServerRepo implements ServerRepo {
  UserServerRepo({
    required Map<String, Server> defaultServers,
    required this.box,
  }) : _defaults = defaultServers;

  final Map<String, Server> _defaults;
  final Box<Server> box;

  /// Presets first in their bundled order (best to worst), then custom ones
  @override
  List<Server> get servers {
    final rank = {for (final (i, k) in _defaults.keys.indexed) k: i};
    final entries = box.toMap().entries.toList()
      ..sort(
        (a, b) =>
            (rank[a.key] ?? rank.length).compareTo(rank[b.key] ?? rank.length),
      );
    return entries.map((it) => it.value).toList();
  }

  Box get _meta => Hive.box(metaKey);

  @override
  Map<String, Server> get defaults => _defaults;

  Future<void> _migrateKeys() async {
    final mapped = Map<String, Server>.from(box.toMap());
    for (final data in mapped.entries) {
      if (data.key.startsWith('@')) {
        continue;
      }
      await box.delete(data.key);
      await box.put(data.value.key, data.value);
    }
    await box.flush();
  }

  /// Keep bundled presets metadata fresh on existing installs without
  /// overriding anything the user has customized.
  Future<void> _syncPresets() async {
    final updates = <String, Server>{};
    for (final entry in box.toMap().entries) {
      final preset = _defaults[entry.key];
      if (preset == null) continue;
      final current = entry.value;
      // the preset moved to another site, replace it unless the user
      // configured credentials for the old one
      if (current.homepage != preset.homepage && !current.hasCredentials) {
        updates[entry.key] = preset;
        continue;
      }
      var synced = current.copyWith(nsfw: preset.nsfw);
      if (current.searchUrl == preset.searchUrl &&
          current.searchParserId.isEmpty) {
        synced = synced.copyWith(searchParserId: preset.searchParserId);
      }
      if (current.tagSuggestionUrl == preset.tagSuggestionUrl &&
          current.suggestionParserId.isEmpty) {
        synced = synced.copyWith(suggestionParserId: preset.suggestionParserId);
      }
      if (current.apiAddr.isEmpty && preset.apiAddr.isNotEmpty) {
        synced = synced.copyWith(apiAddr: preset.apiAddr);
      }
      if (synced != current) updates[entry.key] = synced;
    }
    if (updates.isNotEmpty) await box.putAll(updates);
  }

  /// Presets dropped from the bundled list, removed from existing installs
  /// once so they can still be re-added by hand afterwards.
  static const _retired = {
    '@e621',
    '@e926',
    '@furbooru',
    '@derpibooru',
    '@tbib',
  };

  Future<void> _removeRetired() async {
    if (_meta.get('retired_v2', defaultValue: false) == true) return;
    await box.deleteAll(_retired.where(box.containsKey));
    await _meta.put('retired_v2', true);
  }

  @override
  Future<void> populate() async {
    if (_defaults.isEmpty) return;
    await _removeRetired();

    final seen = Set<String>.from(_meta.get('presets', defaultValue: []));
    if (box.isEmpty) {
      await box.putAll(_defaults);
    } else {
      await _migrateKeys();
      await _syncPresets();
      // add presets introduced by app updates, but never re-add one that
      // the user removed
      final added = Map.fromEntries(
        _defaults.entries.where(
          (it) => !seen.contains(it.key) && !box.containsKey(it.key),
        ),
      );
      if (seen.isNotEmpty && added.isNotEmpty) await box.putAll(added);
      if (seen.isEmpty) {
        // first run with tracking: add what's missing once
        final missing = Map.fromEntries(
          _defaults.entries.where((it) => !box.containsKey(it.key)),
        );
        await box.putAll(missing);
      }
    }
    await _meta.put('presets', _defaults.keys.toList());
  }

  @override
  Future<void> add(Server data) async {
    await box.put(
      data.key,
      data.apiAddr == data.homepage ? data.copyWith(apiAddr: '') : data,
    );
  }

  @override
  Future<Server> edit(Server from, Server to) async {
    final data = to.apiAddr == to.homepage
        ? to.copyWith(id: from.id, apiAddr: '')
        : to.copyWith(id: from.id);

    await box.put(from.key, data);
    return data;
  }

  @override
  Future<void> reset() async {
    await box.deleteAll(box.keys);
    await box.putAll(_defaults);
  }

  @override
  Future<void> remove(Server data) async {
    await box.delete(data.key);
  }

  @override
  Future<void> import(String src) async {
    final List maps = jsonDecode(src);
    if (maps.isEmpty) return;
    await box.deleteAll(box.keys);
    for (final map in maps) {
      if (map is Map<String, dynamic>) {
        final server = Server.fromJson(map);
        await add(server);
      }
    }
  }

  @override
  Future<BackupItem> export() async {
    return BackupItem(key, box.values.map((e) => e.toJson()).toList());
  }

  static const String key = 'server';
  static const String metaKey = 'server_meta';

  static Future<void> prepare() async {
    await Hive.openBox<Server>(key);
    await Hive.openBox(metaKey);
  }
}
