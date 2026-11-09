import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';

/// Danbooru-style blacklist.
///
/// Each [BooruTag.name] is a rule made of whitespace separated terms that
/// must *all* match for a post to be hidden:
///
/// * `tag`            exact tag (case-insensitive)
/// * `tag*`, `*tag*`  wildcard
/// * `-tag`           post must NOT have this tag
/// * `rating:e`       rating metatag (`s`/`g`, `q`, `e`, `sensitive`, ...)
/// * `score:<0`       score metatag (`<`, `<=`, `>`, `>=`, `=`)
///
/// e.g. `animated -sound` hides animated posts without sound.
class Blacklist {
  Blacklist._(this.rules, this._exact);

  factory Blacklist.compile(Iterable<BooruTag> tags, {String serverId = ''}) {
    final rules = <BlacklistRule>[];
    final exact = <String>{};
    final seen = <String>{};
    for (final tag in tags) {
      if (tag.serverId.isNotEmpty && tag.serverId != serverId) continue;
      final rule = BlacklistRule.parse(tag.name);
      if (rule == null || !seen.add(rule.source)) continue;
      // fast path for the most common rule: a single plain tag
      final single = rule.singleTag;
      if (single != null) {
        exact.add(single);
      } else {
        rules.add(rule);
      }
    }
    return Blacklist._(rules, exact);
  }

  static final empty = Blacklist._(const [], const {});

  final List<BlacklistRule> rules;
  final Set<String> _exact;

  bool get isEmpty => rules.isEmpty && _exact.isEmpty;

  /// Whether [post] should be hidden
  bool matches(Post post) {
    if (isEmpty) return false;
    final tags = tagSetOf(post);
    for (final tag in tags) {
      if (_exact.contains(tag)) return true;
    }
    if (rules.isEmpty) return false;
    final rating = BooruRating.parse(post.rateValue);
    for (final rule in rules) {
      if (rule.matches(tags, rating, post.score)) return true;
    }
    return false;
  }

  /// Whether a single [tag] is blocked by any single-term rule. Used to hide
  /// tag suggestions and to reject searching for blocked tags.
  bool blocksTag(String tag) {
    final t = tag.toLowerCase();
    if (_exact.contains(t)) return true;
    for (final rule in rules) {
      if (rule.terms.length == 1 && rule.terms.first.matchesTag(t)) {
        return true;
      }
    }
    return false;
  }

  static Set<String> tagSetOf(Post post) {
    return {
      for (final t in post.tags) t.toLowerCase(),
      for (final t in post.tagsArtist) t.toLowerCase(),
      for (final t in post.tagsCharacter) t.toLowerCase(),
      for (final t in post.tagsCopyright) t.toLowerCase(),
      for (final t in post.tagsGeneral) t.toLowerCase(),
      for (final t in post.tagsMeta) t.toLowerCase(),
    };
  }

  /// Split user input into rules. Rules are separated by new lines or commas,
  /// terms inside a rule are separated by spaces.
  static List<String> splitInput(String input) {
    return input
        .split(RegExp(r'[\n,]'))
        .map((it) => it.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((it) => it.isNotEmpty)
        .toList();
  }
}

class BlacklistRule {
  const BlacklistRule._(this.source, this.terms);

  /// Rules made only of negations are rejected unless [allowOnlyNegation],
  /// as they would hide nearly everything in a blacklist.
  static BlacklistRule? parse(String input, {bool allowOnlyNegation = false}) {
    final words = input
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((it) => it.isNotEmpty && it != '-');
    final terms = words.map(BlacklistTerm.parse).toList();
    if (terms.isEmpty) return null;
    if (!allowOnlyNegation && terms.every((it) => it.negated)) return null;
    return BlacklistRule._(words.join(' '), terms);
  }

  final String source;
  final List<BlacklistTerm> terms;

  String? get singleTag {
    if (terms.length != 1) return null;
    final term = terms.first;
    return term is _TagTerm && !term.negated && !term.isWildcard
        ? term.value
        : null;
  }

  bool matches(Set<String> tags, BooruRating rating, int score) {
    for (final term in terms) {
      if (term.matches(tags, rating, score) == term.negated) return false;
    }
    return true;
  }
}

sealed class BlacklistTerm {
  const BlacklistTerm(this.negated);

  factory BlacklistTerm.parse(String word) {
    final negated = word.startsWith('-');
    final body = negated ? word.substring(1) : word;
    if (body.startsWith('rating:')) {
      final value = body.substring(7);
      return _RatingTerm(negated, BooruRating.parse(value));
    }
    if (body.startsWith('score:')) {
      final term = _ScoreTerm.tryParse(negated, body.substring(6));
      if (term != null) return term;
    }
    return _TagTerm(negated, body);
  }

  final bool negated;

  bool matches(Set<String> tags, BooruRating rating, int score);

  bool matchesTag(String tag) => false;
}

class _TagTerm extends BlacklistTerm {
  _TagTerm(super.negated, this.value)
    : isWildcard = value.contains('*'),
      _pattern = value.contains('*')
          ? RegExp('^${value.split('*').map(RegExp.escape).join('.*')}\$')
          : null;

  final String value;
  final bool isWildcard;
  final RegExp? _pattern;

  @override
  bool matchesTag(String tag) {
    final pattern = _pattern;
    return pattern == null ? tag == value : pattern.hasMatch(tag);
  }

  @override
  bool matches(Set<String> tags, BooruRating rating, int score) {
    if (!isWildcard) return tags.contains(value);
    return tags.any(matchesTag);
  }
}

class _RatingTerm extends BlacklistTerm {
  const _RatingTerm(super.negated, this.rating);

  final BooruRating rating;

  @override
  bool matches(Set<String> tags, BooruRating rating, int score) =>
      rating == this.rating;
}

class _ScoreTerm extends BlacklistTerm {
  const _ScoreTerm(super.negated, this.op, this.value);

  static _ScoreTerm? tryParse(bool negated, String input) {
    final match = RegExp(r'^(<=|>=|<|>|=)?(-?\d+)$').firstMatch(input);
    if (match == null) return null;
    return _ScoreTerm(
      negated,
      match.group(1) ?? '=',
      int.parse(match.group(2)!),
    );
  }

  final String op;
  final int value;

  @override
  bool matches(Set<String> tags, BooruRating rating, int score) {
    return switch (op) {
      '<' => score < value,
      '<=' => score <= value,
      '>' => score > value,
      '>=' => score >= value,
      _ => score == value,
    };
  }
}
