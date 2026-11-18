import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:dio/dio.dart';

/// nekosia.cat: tagged anime art, served in random batches of 20.
/// Tags use dashes ("animal-ears"), searches are mapped to them.
class NekosiaJsonParser extends BooruParser {
  @override
  final id = 'Nekosia.json';

  @override
  final searchQuery = 'api/v1/images/random?count=20&tags={tags}';

  @override
  final suggestionQuery = 'api/v1/tags?q={tag-part}';

  @override
  List<BooruParserType> get type => [
    BooruParserType.search,
    BooruParserType.suggestion,
  ];

  static String searchUrlOf(String apiAddress, String query) {
    final tags = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((it) => it.isNotEmpty && it != '*' && !it.contains(':'))
        .map((it) => it.toLowerCase().replaceAll('_', '-'))
        .join(',');
    final filter = tags.isEmpty
        ? ''
        : '&tags=${Uri.encodeQueryComponent(tags)}';
    return '$apiAddress/api/v1/images/random?count=20$filter';
  }

  @override
  bool canParsePage(Response res) {
    final data = res.data;
    return data is Map &&
        data['images'] is List &&
        data.toString().contains('nekosia');
  }

  @override
  List<Post> parsePage(Server server, Response res) {
    final entries = List.from(res.data['images']);
    final result = <Post>[];
    for (final post in entries.whereType<Map<String, dynamic>>()) {
      final rawId = pick(post, 'id').asStringOrNull() ?? '';
      final id = rawId.length >= 12
          ? int.tryParse(rawId.substring(0, 12), radix: 16) ?? -1
          : -1;
      final original = pick(post, 'image', 'original', 'url').asStringOrNull();
      final compressed = pick(
        post,
        'image',
        'compressed',
        'url',
      ).asStringOrNull();
      final width =
          pick(post, 'metadata', 'original', 'width').asIntOrNull() ?? -1;
      final height =
          pick(post, 'metadata', 'original', 'height').asIntOrNull() ?? -1;
      if (id < 0 || original == null || width <= 0 || height <= 0) continue;
      if (result.any((it) => it.id == id)) continue;

      final tags = pick(post, 'tags').asListOrEmpty((it) => it.asString());
      final rating = pick(post, 'rating').asStringOrNull() ?? 'safe';
      result.add(
        Post(
          id: id,
          originalFile: original,
          sampleFile: compressed ?? '',
          previewFile: compressed ?? original,
          tags: [for (final tag in tags) tag.replaceAll('-', '_')],
          width: width,
          height: height,
          serverId: server.id,
          postUrl: server.homepage,
          rateValue: rating == 'safe' ? 'safe' : 'questionable',
          source:
              pick(post, 'source', 'url').asStringOrNull() ??
              pick(post, 'attribution', 'artist', 'profile').asStringOrNull() ??
              '',
        ),
      );
    }
    return result;
  }

  @override
  bool canParseSuggestion(Response res) {
    final data = res.data;
    return data is Map && data['tags'] is List;
  }

  @override
  Iterable<String> parseSuggestion(Server server, Response res) {
    final part = (res.realUri.queryParameters['q'] ?? '')
        .replaceAll('*', '')
        .toLowerCase()
        .replaceAll('_', '-');
    return List<String>.from(res.data['tags'])
        .where((it) => it.contains(part))
        .take(Server.tagSuggestionLimit)
        .map((it) => it.replaceAll('-', '_'));
  }
}
