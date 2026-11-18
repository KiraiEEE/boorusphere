import 'dart:convert';

import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/entity/search_sort.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:dio/dio.dart';

/// zerochan.net, a large anime art gallery.
///
/// Its list JSON comes back with a 500 status and HTML glued around it, so
/// the response is read as text and the `items` array is cut out by hand.
/// Tags are titles like "Hatsune Miku"; several are joined with commas.
class ZerochanJsonParser extends BooruParser {
  @override
  final id = 'Zerochan.json';

  @override
  final searchQuery = '{tags}?json&l={post-limit}&p={page-id}';

  @override
  ResponseType get responseType => ResponseType.plain;

  @override
  bool acceptsStatus(int? code) => code == 200 || code == 500;

  @override
  List<BooruParserType> get type => [BooruParserType.search];

  /// Endpoint for [query] on the 0-based [page]
  static String searchUrlOf(
    String apiAddress,
    String query,
    int page,
    int limit,
    SearchSort sort,
  ) {
    final tags = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((it) => it.isNotEmpty && it != '*' && !it.contains(':'))
        .map((it) => it.replaceAll('_', ' '))
        .map(Uri.encodeComponent)
        .join(',');
    // the API allows up to 250, but a big page is slow to arrive
    final count = limit.clamp(1, 100);
    final order = sort == SearchSort.popular ? '&s=fav&t=1' : '&s=id';
    return '$apiAddress/$tags?json&l=$count&p=${page + 1}$order';
  }

  /// Full size file for a post, the list doesn't say if it's a png or jpg
  static String detailUrlOf(int id) => 'https://www.zerochan.net/$id?json';

  static bool isGuessedOriginal(String url) =>
      url.startsWith('https://static.zerochan.net/.full.');

  /// The `items` array out of a response that isn't valid JSON as a whole
  static List<dynamic> itemsOf(Object? data) {
    if (data is Map) return List.from(data['items'] ?? const []);
    if (data is! String) return const [];
    final key = data.indexOf('"items"');
    if (key < 0) return const [];
    final start = data.indexOf('[', key);
    if (start < 0) return const [];
    var depth = 0;
    var inString = false;
    for (var i = start; i < data.length; i++) {
      final c = data[i];
      if (inString) {
        if (c == r'\') {
          i++;
        } else if (c == '"') {
          inString = false;
        }
      } else if (c == '"') {
        inString = true;
      } else if (c == '[') {
        depth++;
      } else if (c == ']' && --depth == 0) {
        try {
          return jsonDecode(data.substring(start, i + 1)) as List;
        } catch (e) {
          return const [];
        }
      }
    }
    return const [];
  }

  @override
  bool canParsePage(Response res) {
    final data = res.data;
    return data is String &&
        data.contains('"items"') &&
        data.contains('zerochan.net');
  }

  @override
  List<Post> parsePage(Server server, Response res) {
    final result = <Post>[];
    for (final post in itemsOf(res.data).whereType<Map<String, dynamic>>()) {
      final id = int.tryParse('${post['id']}') ?? -1;
      final width = int.tryParse('${post['width']}') ?? -1;
      final height = int.tryParse('${post['height']}') ?? -1;
      if (id < 0 || width <= 0 || height <= 0) continue;
      if (result.any((it) => it.id == id)) continue;

      // the listed thumbnail is AVIF, the same path also exists as JPEG
      final thumbnail = pick(post, 'thumbnail').asStringOrNull() ?? '';
      final preview = thumbnail.isEmpty
          ? 'https://s1.zerochan.net/.240.$id.jpg'
          : thumbnail.replaceFirst(RegExp(r'\.avif$'), '.jpg');
      final tags = pick(post, 'tags').asListOrEmpty((it) => it.asString());

      result.add(
        Post(
          id: id,
          // corrected from the post details when it's downloaded
          originalFile: 'https://static.zerochan.net/.full.$id.jpg',
          sampleFile: 'https://s1.zerochan.net/.600.$id.jpg',
          previewFile: preview,
          tags: [
            for (final tag in tags)
              tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
          ],
          width: width,
          height: height,
          serverId: server.id,
          postUrl: 'https://www.zerochan.net/$id',
          // zerochan doesn't allow explicit art
          rateValue: 'safe',
          source: pick(post, 'source').asStringOrNull() ?? '',
        ),
      );
    }
    return result;
  }
}
