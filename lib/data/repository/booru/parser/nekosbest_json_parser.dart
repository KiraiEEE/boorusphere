import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:dio/dio.dart';

/// nekos.best: safe anime reaction GIFs, no account needed.
///
/// There are no tags, only reaction categories (hug, pat, dance, ...) and a
/// search over anime titles, so [Server.searchUrlOf] picks the endpoint:
/// a category name gets random GIFs of it, anything else searches titles,
/// and an empty search walks through the categories page by page.
class NekosBestJsonParser extends BooruParser {
  @override
  final id = 'NekosBest.json';

  @override
  final searchQuery = 'api/v2/search?query={tags}&type=2&amount=20';

  @override
  final suggestionQuery = 'api/v2/endpoints?q={tag-part}';

  @override
  List<BooruParserType> get type => [
    BooruParserType.search,
    BooruParserType.suggestion,
  ];

  /// The API never returns more than this per request
  static const pageSize = 20;

  /// Reactions that come as GIFs, in the order the home feed shows them
  static const categories = [
    'hug', 'pat', 'smile', 'wave', 'happy', 'dance', 'cuddle', 'blush', //
    'laugh', 'wink', 'smug', 'thumbsup', 'highfive', 'nod', 'clap',
    'kiss', 'peck', 'blowkiss', 'handhold', 'handshake', 'lappillow',
    'cry', 'pout', 'sleep', 'yawn', 'bored', 'think', 'confused', 'shrug',
    'stare', 'lurk', 'nope', 'facepalm', 'shocked', 'teehee', 'bleh',
    'nya', 'nom', 'feed', 'sip', 'wag', 'spin', 'run', 'carry', 'salute',
    'tickle', 'poke', 'baka', 'bonk', 'bite', 'angry', 'kick', 'punch',
    'slap', 'shoot', 'yeet', 'shake', 'kabedon', 'tableflip',
  ];

  /// Endpoint for [query] on the 0-based [page]
  static String searchUrlOf(String apiAddress, String query, int page) {
    final words = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((it) => it.isNotEmpty && it != '*' && !it.contains(':'))
        .toList();
    final first = words.firstOrNull?.toLowerCase() ?? '';
    if (categories.contains(first)) {
      return '$apiAddress/api/v2/$first?amount=$pageSize';
    }

    // titles need at least 3 characters, otherwise show the reaction feed
    final title = words.join(' ').replaceAll('_', ' ');
    if (title.length >= 3) {
      return '$apiAddress/api/v2/search'
          '?query=${Uri.encodeQueryComponent(title)}&type=2&amount=$pageSize';
    }
    final category = categories[page % categories.length];
    return '$apiAddress/api/v2/$category?amount=$pageSize';
  }

  @override
  bool canParsePage(Response res) {
    final data = res.data;
    return data is Map &&
        data['results'] is List &&
        data.toString().contains('anime_name');
  }

  @override
  List<Post> parsePage(Server server, Response res) {
    final entries = List.from(res.data['results']);
    final result = <Post>[];
    for (final post in entries.whereType<Map<String, dynamic>>()) {
      final url = pick(post, 'url').asStringOrNull() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || !url.endsWith('.gif')) continue;

      // https://nekos.best/api/v2/<category>/<uuid>.gif
      final segments = uri.pathSegments;
      if (segments.length < 2) continue;
      final category = segments[segments.length - 2];
      final uuid = segments.last.split('.').first.replaceAll('-', '');
      // first 48 bits of the uuid, plenty to tell GIFs apart
      final id = uuid.length >= 12
          ? int.tryParse(uuid.substring(0, 12), radix: 16) ?? -1
          : -1;
      final width = pick(post, 'dimensions', 'width').asIntOrNull() ?? -1;
      final height = pick(post, 'dimensions', 'height').asIntOrNull() ?? -1;
      final anime = pick(post, 'anime_name').asStringOrNull() ?? '';

      if (id < 0 || width <= 0 || height <= 0) continue;
      if (result.any((it) => it.id == id)) continue;

      result.add(
        Post(
          id: id,
          originalFile: url,
          previewFile: url,
          tags: [
            category,
            if (anime.isNotEmpty)
              anime.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
            'animated_gif',
          ],
          width: width,
          height: height,
          serverId: server.id,
          postUrl: server.homepage,
          rateValue: 'safe',
        ),
      );
    }
    return result;
  }

  @override
  bool canParseSuggestion(Response res) {
    final data = res.data;
    return data is Map && data['hug'] is Map;
  }

  @override
  Iterable<String> parseSuggestion(Server server, Response res) {
    final part = (res.realUri.queryParameters['q'] ?? '')
        .replaceAll('*', '')
        .toLowerCase();
    return categories.where((it) => it.contains(part));
  }
}
