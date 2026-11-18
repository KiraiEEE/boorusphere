import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/entity/search_sort.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:dio/dio.dart';

/// redgifs.com: adult GIFs and short clips. Every request needs a guest
/// token, which the site hands out without an account and which lasts a day.
class RedgifsJsonParser extends BooruParser {
  @override
  final id = 'Redgifs.json';

  @override
  final searchQuery =
      'v2/gifs/search?search_text={tags}&count={post-limit}&page={page-id}';

  @override
  List<BooruParserType> get type => [BooruParserType.search];

  static String? _token;
  static DateTime _expiry = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<Map<String, String>> headersFor(Dio client) async {
    if (_token == null || DateTime.now().isAfter(_expiry)) {
      final res = await client.get('https://api.redgifs.com/v2/auth/temporary');
      _token = pick(res.data, 'token').asStringOrNull();
      // tokens last 24 hours, renew a little early
      _expiry = DateTime.now().add(const Duration(hours: 20));
    }
    final token = _token;
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  static String searchUrlOf(
    String apiAddress,
    String query,
    int page,
    int limit,
    SearchSort sort,
  ) {
    final text = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((it) => it.isNotEmpty && it != '*' && !it.contains(':'))
        .map((it) => it.replaceAll('_', ' '))
        .join(' ');
    final order = switch (sort) {
      SearchSort.popular => 'top',
      SearchSort.random => 'trending',
      SearchSort.latest => text.isEmpty ? 'trending' : 'latest',
    };
    final search = text.isEmpty
        ? ''
        : 'search_text=${Uri.encodeQueryComponent(text)}&';
    return '$apiAddress/v2/gifs/search?${search}order=$order'
        '&count=${limit.clamp(1, 80)}&page=${page + 1}';
  }

  @override
  bool canParsePage(Response res) {
    final data = res.data;
    return data is Map && data['gifs'] is List;
  }

  @override
  List<Post> parsePage(Server server, Response res) {
    final entries = List.from(res.data['gifs']);
    final result = <Post>[];
    for (final post in entries.whereType<Map<String, dynamic>>()) {
      final slug = pick(post, 'id').asStringOrNull() ?? '';
      final hd = pick(post, 'urls', 'hd').asStringOrNull() ?? '';
      final sd = pick(post, 'urls', 'sd').asStringOrNull() ?? '';
      final thumbnail =
          pick(post, 'urls', 'thumbnail').asStringOrNull() ??
          pick(post, 'urls', 'poster').asStringOrNull() ??
          '';
      final width = pick(post, 'width').asIntOrNull() ?? -1;
      final height = pick(post, 'height').asIntOrNull() ?? -1;
      if (slug.isEmpty || (hd.isEmpty && sd.isEmpty) || thumbnail.isEmpty) {
        continue;
      }
      if (width <= 0 || height <= 0) continue;
      final id = numericIdOf(slug);
      if (result.any((it) => it.id == id)) continue;

      final tags = pick(post, 'tags').asListOrEmpty((it) => it.asString());
      result.add(
        Post(
          id: id,
          originalFile: hd.isNotEmpty ? hd : sd,
          sampleFile: sd,
          previewFile: thumbnail,
          tags: [
            for (final tag in tags)
              tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
          ],
          width: width,
          height: height,
          serverId: server.id,
          postUrl: 'https://www.redgifs.com/watch/$slug',
          rateValue: 'explicit',
          score: pick(post, 'likes').asIntOrNull() ?? 0,
        ),
      );
    }
    return result;
  }
}
