import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/tags_blocker/blacklist.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';

/// Splits a search query between what the server can handle and what has to
/// be filtered locally, for servers that limit how many tags can be searched
/// at once (e.g. anonymous Danbooru users are limited to 2 tags).
class TagQuery {
  const TagQuery._(this.server, this._local);

  factory TagQuery.split(String query, {int? limit}) {
    final words =
        query.trim().split(RegExp(r'\s+')).where((it) => it.isNotEmpty);
    if (limit == null || limit <= 0) {
      return TagQuery._(words.join(' '), null);
    }

    final server = <String>[];
    final local = <String>[];
    var counted = 0;
    // Positive tags narrow results the most, so send them first.
    final ordered = [
      ...words.where((it) => !it.startsWith('-') && !_isMetatag(it)),
      ...words.where((it) => it.startsWith('-') && !_isMetatag(it)),
    ];
    for (final word in ordered) {
      if (counted < limit) {
        server.add(word);
        counted++;
      } else {
        local.add(word);
      }
    }
    // metatags like rating: or order: are not counted by servers
    server.addAll(words.where(_isMetatag));

    return TagQuery._(
      server.join(' '),
      local.isEmpty ? null : BlacklistRule.parse(local.join(' ')),
    );
  }

  /// Query to send to the server
  final String server;

  final BlacklistRule? _local;

  bool get hasLocalFilter => _local != null;

  /// Whether [post] satisfies the tags that couldn't be sent to the server
  bool accepts(Post post) {
    final rule = _local;
    if (rule == null) return true;
    return rule.matches(
      Blacklist.tagSetOf(post),
      BooruRating.parse(post.rateValue),
      post.score,
    );
  }

  static bool _isMetatag(String word) {
    final body = word.startsWith('-') ? word.substring(1) : word;
    final colon = body.indexOf(':');
    // "re:zero" style tags have short prefixes that aren't metatags
    return colon > 2 && _metatags.contains(body.substring(0, colon));
  }

  static const _metatags = {
    'rating',
    'order',
    'sort',
    'limit',
    'status',
    'score',
    'safety',
  };

  /// Extract the limit from a "tag limit" error returned by the server.
  static int? parseLimitError(Object? data) {
    final text = data?.toString() ?? '';
    if (!text.contains('TagLimitError') &&
        !RegExp('more than .* tags', caseSensitive: false).hasMatch(text)) {
      return null;
    }
    final match = RegExp(r'more than (\w+) tags', caseSensitive: false)
        .firstMatch(text);
    final value = match?.group(1)?.toLowerCase();
    if (value == null) return null;
    return int.tryParse(value) ?? _words[value];
  }

  static const _words = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
  };
}
