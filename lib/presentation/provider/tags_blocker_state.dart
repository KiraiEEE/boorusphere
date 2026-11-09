import 'package:boorusphere/data/repository/tags_blocker/blacklist.dart';
import 'package:boorusphere/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorusphere/domain/provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tags_blocker_state.g.dart';

@Riverpod(keepAlive: true)
class TagsBlockerState extends _$TagsBlockerState {
  @override
  Map<int, BooruTag> build() {
    final repo = ref.read(tagsBlockerRepoProvider);
    return repo.get();
  }

  Future<void> delete(key) async {
    final repo = ref.read(tagsBlockerRepoProvider);
    await repo.delete(key);
    state = repo.get();
  }

  Future<void> push({
    String serverId = '',
    required String tag,
  }) async {
    final repo = ref.read(tagsBlockerRepoProvider);
    await repo.push(BooruTag(serverId: serverId, name: tag));
    state = repo.get();
  }

  Future<void> pushAll({
    String serverId = '',
    required Iterable<String> tags,
  }) async {
    final repo = ref.read(tagsBlockerRepoProvider);
    for (final tag in tags) {
      await repo.push(BooruTag(serverId: serverId, name: tag));
    }
    state = repo.get();
  }

  /// Re-add previously removed entries (used for undo)
  Future<void> restore(Iterable<BooruTag> tags) async {
    final repo = ref.read(tagsBlockerRepoProvider);
    for (final tag in tags) {
      await repo.push(tag);
    }
    state = repo.get();
  }
}

/// Compiled blacklist for [serverId], recomputed only when rules change.
@Riverpod(keepAlive: true)
Blacklist blacklist(Ref ref, String serverId) {
  final tags = ref.watch(tagsBlockerStateProvider).values;
  return Blacklist.compile(tags, serverId: serverId);
}
