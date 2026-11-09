import 'dart:collection';
import 'dart:convert';

import 'package:boorusphere/data/repository/booru/entity/booru_error.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/booru/utils/booru_util.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/utils/extensions/pick.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:dio/dio.dart';
import 'package:xml2json/xml2json.dart';

class ShimmieXmlParser extends BooruParser {
  @override
  final id = 'Shimmie.xml';

  @override
  final postUrl = 'post/view/{post-id}';

  @override
  final searchQuery =
      'api/danbooru/find_posts?tags={tags}&limit={post-limit}&page={page-id}';

  @override
  final suggestionQuery = 'api/internal/autocomplete?s={tag-part}';

  @override
  List<BooruParserType> get type => [
    BooruParserType.search,
    BooruParserType.suggestion,
  ];

  @override
  bool canParsePage(Response res) {
    final data = res.data;
    final rawString = data.toString();
    // older Shimmie uses <tag> elements, newer ones use <post>
    return data is String &&
        rawString.contains('<posts') &&
        (rawString.contains('<tag ') || rawString.contains('<post '));
  }

  @override
  List<Post> parsePage(Server server, Response res) {
    final entries = [];
    final xjson = Xml2Json();
    xjson.parse(res.data.replaceAll('\\', ''));

    final conv = jsonDecode(xjson.toGData());

    final root = conv.values.first;
    final key = root.keys.contains('post') ? 'post' : 'tag';
    if (!root.keys.contains(key)) {
      throw BooruError.empty;
    }

    final posts = root[key];

    if (posts is LinkedHashMap) {
      entries.add(posts);
    } else if (posts is List) {
      entries.addAll(posts);
    } else {
      throw BooruError.empty;
    }

    final result = <Post>[];

    for (final post in entries.whereType<Map<String, dynamic>>()) {
      final id = pick(post, 'id').asIntOrNull() ?? -1;
      if (result.any((it) => it.id == id)) {
        // duplicated result, skipping
        continue;
      }

      final originalFile = pick(post, 'file_url').asStringOrNull() ?? '';
      final sampleFile = pick(post, 'sample_url').asStringOrNull() ?? '';
      final previewFile = pick(post, 'preview_url').asStringOrNull() ?? '';
      final tags = pick(post, 'tags').toWordList();
      final width = pick(post, 'width').asIntOrNull() ?? -1;
      final height = pick(post, 'height').asIntOrNull() ?? -1;
      final sampleWidth = pick(post, 'sample_width').asIntOrNull() ?? -1;
      final sampleHeight = pick(post, 'sample_height').asIntOrNull() ?? -1;
      final previewWidth = pick(post, 'preview_width').asIntOrNull() ?? -1;
      final previewHeight = pick(post, 'preview_height').asIntOrNull() ?? -1;
      final rating = pick(post, 'rating').asStringOrNull() ?? 'q';
      final source = pick(post, 'source').asStringOrNull() ?? '';
      final score = pick(post, 'score').asIntOrNull() ?? 0;

      final hasFile = originalFile.isNotEmpty && previewFile.isNotEmpty;
      final hasContent = width > 0 && height > 0;
      final postUrl = server.postUrlOf(id);

      if (hasFile && hasContent) {
        result.add(
          Post(
            id: id,
            originalFile: BooruUtil.normalizeUrl(server, originalFile),
            sampleFile: BooruUtil.normalizeUrl(server, sampleFile),
            previewFile: BooruUtil.normalizeUrl(server, previewFile),
            tags: tags.map(BooruUtil.decodeTag).toList(),
            width: width,
            height: height,
            sampleWidth: sampleWidth,
            sampleHeight: sampleHeight,
            previewWidth: previewWidth,
            previewHeight: previewHeight,
            serverId: server.id,
            postUrl: postUrl,
            rateValue: rating.isEmpty ? 'q' : rating,
            source: source,
            score: score,
          ),
        );
      }
    }
    return result;
  }

  @override
  bool canParseSuggestion(Response res) {
    final data = res.data;
    return data is Map &&
        data.values.every(
          (it) => it is int || (it is Map && it['count'] is int),
        );
  }

  // {"tag": 12} on older Shimmie, {"tag": {"count": 12}} on newer ones
  static int _countOf(Object? value) {
    if (value is int) return value;
    if (value is Map && value['count'] is int) return value['count'];
    return 0;
  }

  @override
  Set<String> parseSuggestion(Server server, Response res) {
    final Map data = res.data;
    return data.entries
        .where((it) => _countOf(it.value) > 0)
        .map((it) => BooruUtil.decodeTag(it.key.toString()))
        .toSet();
  }
}
