import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:dio/dio.dart';

/// wallhaven.cc wallpaper search
class WallhavenJsonParser extends BooruParser {
  @override
  final id = 'Wallhaven.json';

  @override
  final searchQuery =
      'api/v1/search?q={tags}&page={page-id}&purity=111&categories=111';

  @override
  final postUrl = 'w/{post-id}';

  @override
  List<BooruParserType> get type => [BooruParserType.search];

  @override
  bool canParsePage(Response res) {
    final data = res.data;
    return data is Map &&
        data['data'] is List &&
        data['meta'] is Map &&
        data.toString().contains('purity');
  }

  @override
  List<Post> parsePage(Server server, Response res) {
    final entries = List.from(res.data['data']);
    final result = <Post>[];
    for (final post in entries.whereType<Map<String, dynamic>>()) {
      // ids are base36 strings like "yqkl97"
      final rawId = pick(post, 'id').asStringOrNull() ?? '';
      final id = int.tryParse(rawId, radix: 36) ?? -1;
      final original = pick(post, 'path').asStringOrNull() ?? '';
      // "original" thumbnail keeps the aspect ratio, "small" is cropped
      final preview = pick(post, 'thumbs', 'original').asStringOrNull() ?? '';
      final width = pick(post, 'dimension_x').asIntOrNull() ?? -1;
      final height = pick(post, 'dimension_y').asIntOrNull() ?? -1;
      final purity = pick(post, 'purity').asStringOrNull() ?? '';
      final category = pick(post, 'category').asStringOrNull() ?? '';

      if (id < 0 || original.isEmpty || preview.isEmpty) continue;
      if (width <= 0 || height <= 0) continue;
      if (result.any((it) => it.id == id)) continue;

      result.add(
        Post(
          id: id,
          originalFile: original,
          previewFile: preview,
          tags: [if (category.isNotEmpty) category, 'wallpaper'],
          width: width,
          height: height,
          serverId: server.id,
          postUrl: pick(post, 'url').asStringOrNull() ?? server.homepage,
          rateValue: switch (purity) {
            'sfw' => 'safe',
            'nsfw' => 'explicit',
            _ => 'questionable',
          },
          source: pick(post, 'source').asStringOrNull() ?? '',
          score: pick(post, 'favorites').asIntOrNull() ?? 0,
        ),
      );
    }
    return result;
  }
}
