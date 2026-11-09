import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/entity/search_sort.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:boorusphere/utils/extensions/string.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive_ce.dart';

part 'server.freezed.dart';
part 'server.g.dart';

@freezed
@HiveType(typeId: 2, adapterName: 'ServerAdapter')
abstract class Server with _$Server {
  const factory Server({
    @HiveField(0, defaultValue: '') @Default('') String id,
    @HiveField(1, defaultValue: '') @Default('') String homepage,
    @HiveField(2, defaultValue: '') @Default('') String postUrl,
    @HiveField(3, defaultValue: '') @Default('') String searchUrl,
    @HiveField(4, defaultValue: '') @Default('') String apiAddr,
    @HiveField(7, defaultValue: '') @Default('') String tagSuggestionUrl,
    @HiveField(8, defaultValue: '') @Default('') String alias,
    @HiveField(9, defaultValue: '') @Default('') String searchParserId,
    @HiveField(10, defaultValue: '') @Default('') String suggestionParserId,
    // User name / user id used for API authentication
    @HiveField(11, defaultValue: '') @Default('') String login,
    // API key used for API authentication
    @HiveField(12, defaultValue: '') @Default('') String apiKey,
    // Whether this server is dedicated to adult content
    @HiveField(13, defaultValue: false) @Default(false) bool nsfw,
    // Whether this server mostly hosts AI generated content
    @HiveField(14, defaultValue: false) @Default(false) bool ai,
  }) = _Server;

  factory Server.fromJson(Map<String, dynamic> json) => _$ServerFromJson(json);

  const Server._();

  bool get canSuggestTags => tagSuggestionUrl.contains('{tag-part}');

  bool get hasCredentials => login.isNotEmpty && apiKey.isNotEmpty;

  /// Gelbooru-like `index.php?page=dapi` APIs
  bool get isDapi => searchUrl.contains('page=dapi');

  RatingDialect get ratingDialect {
    if (searchParserId == 'Wallhaven.json') {
      // rating is filtered with the "purity" parameter instead
      return RatingDialect.none;
    } else if (searchUrl.toUri().queryParameters.containsKey('offset')) {
      return RatingDialect.szurubooru;
    } else if (searchUrl.contains('api/v1/json/search')) {
      return RatingDialect.booruOnRails;
    }

    // Danbooru (and forks) and Gelbooru 0.2.5 replaced "safe" with
    // "general" + "sensitive". The resolved parser is the reliable hint here
    // since e621 shares Danbooru's url scheme but not its ratings.
    const modernParsers = {'Danbooru.json', 'Gelbooru.json', 'Gelbooru.xml'};
    return modernParsers.contains(searchParserId)
        ? RatingDialect.modern
        : RatingDialect.legacy;
  }

  String searchUrlOf(PageOption option, {required int page}) {
    final query = option.query.trim();
    var tags = query.isEmpty ? Server.defaultTag : query;
    final rate = ratingDialect.tagOf(option.searchRating);
    if (ratingDialect == RatingDialect.booruOnRails) {
      // booru-on-rails uses plain tags for rating
      tags = tags.replaceAll('rating:', '');
    }
    if (rate.isNotEmpty) {
      tags += ' $rate';
    }
    final sortTag = _sortTagOf(option.sort);
    if (sortTag.isNotEmpty) {
      tags += ' $sortTag';
    }

    if (ratingDialect == RatingDialect.booruOnRails) {
      // booru-on-rails tags contain spaces and are separated by commas
      tags = tags
          .trim()
          .split(RegExp(r'\s+'))
          .map((it) => it.replaceAll('_', ' '))
          .join(',');
    }

    tags = Uri.encodeComponent(tags.trim());

    final url = '$apiAddress/$searchUrl'
        .replaceAll('{tags}', tags)
        // [page] is 0-based; only gelbooru's "pid" is, page numbers start at 1
        .replaceAll(
          '{page-id}',
          '${searchUrl.contains('pid={page-id}') ? page : page + 1}',
        )
        .replaceAll('{post-offset}', (page * option.limit).toString())
        .replaceAll('{post-limit}', '${option.limit}');
    var result = url + _sortParamOf(option.sort);
    if (searchParserId == 'Wallhaven.json' &&
        option.searchRating == BooruRating.safe) {
      // purity flags: sfw/sketchy/nsfw
      result = result.replaceFirst(RegExp(r'purity=\d{3}'), 'purity=100');
    }
    return withAuth(result);
  }

  /// Sorting expressed as a search metatag
  String _sortTagOf(SearchSort sort) {
    if (sort == SearchSort.latest) return '';
    final popular = sort == SearchSort.popular;
    return switch (searchParserId) {
      'Danbooru.json' ||
      'Moebooru.json' ||
      'E621.json' => popular ? 'order:score' : 'order:random',
      'Safebooru.xml' ||
      'Gelbooru.json' ||
      'Gelbooru.xml' => popular ? 'sort:score:desc' : 'sort:random',
      'Szurubooru.json' => popular ? 'sort:score' : 'sort:random',
      'Shimmie.xml' => popular ? 'order:score_desc' : '',
      _ => '',
    };
  }

  /// Sorting expressed as a url parameter
  String _sortParamOf(SearchSort sort) {
    final popular = sort == SearchSort.popular;
    return switch (searchParserId) {
      'Wallhaven.json' => switch (sort) {
        SearchSort.latest => '&sorting=date_added',
        _ => popular ? '&sorting=toplist' : '&sorting=random',
      },
      'BooruOnRails.json' when sort != SearchSort.latest =>
        popular ? '&sf=score&sd=desc' : '&sf=random',
      _ => '',
    };
  }

  /// Whether this server can order results by [sort]
  bool supportsSort(SearchSort sort) =>
      sort == SearchSort.latest ||
      _sortTagOf(sort).isNotEmpty ||
      _sortParamOf(sort).isNotEmpty;

  String suggestionUrlsOf(String query) {
    final url = '$apiAddress/$tagSuggestionUrl'
        .replaceAll('{post-limit}', '$tagSuggestionLimit')
        .replaceAll('{tag-limit}', '$tagSuggestionLimit')
        // a bare "%" wildcard would merge with the query into an escape
        // sequence (e.g. "%ca" from "cat"), so send it encoded
        .replaceAll('%{tag-part}%', '%25{tag-part}%25');

    final encq = Uri.encodeComponent(
      ratingDialect == RatingDialect.booruOnRails
          ? query.replaceAll('_', ' ')
          : query,
    );
    if (!canSuggestTags) {
      throw Exception('no suggestion config for server $name');
    }

    if (query.isEmpty) {
      if (url.contains('name_pattern=')) {
        return withAuth(
          url.replaceAll(RegExp(r'(%25|[*%])*{tag-part}(%25|[*%])*'), ''),
        );
      }
      return withAuth(
        url.replaceAll(RegExp(r'(%25|[*%])*{tag-part}(%25|[*%])*'), '*'),
      );
    }
    return withAuth(url.replaceAll('{tag-part}', encq));
  }

  /// Append API credentials to [url] using the convention of the server.
  String withAuth(String url) {
    if (!hasCredentials) return url;
    final user = Uri.encodeQueryComponent(login.trim());
    final key = Uri.encodeQueryComponent(apiKey.trim());
    final sep = url.contains('?') ? '&' : '?';
    if (url.contains('page=dapi')) {
      // Gelbooru, Rule34.xxx and other gelbooru-based servers
      return '$url${sep}api_key=$key&user_id=$user';
    }
    // Danbooru, e621 and most danbooru-compatible servers
    return '$url${sep}login=$user&api_key=$key';
  }

  String postUrlOf(int id) {
    if (postUrl.isEmpty) {
      return homepage;
    }

    final query = postUrl.replaceAll('{post-id}', id.toString());
    return '$homepage/$query';
  }

  // Key used in hive box
  String get key {
    final asKey = id.replaceAll(RegExp('[^A-Za-z0-9]'), '-');
    return '@${asKey.toLowerCase()}';
  }

  String get apiAddress => apiAddr.isEmpty ? homepage : apiAddr;

  String get name => alias.isNotEmpty ? alias : id;

  static const Server empty = Server();
  static const String defaultTag = '*';
  static const tagSuggestionLimit = 20;
}

/// How a server expects the rating to be expressed in search query
enum RatingDialect {
  /// safe / questionable / explicit (Moebooru, Gelbooru 0.2, e621, ...)
  legacy,

  /// general / sensitive / questionable / explicit (Danbooru, Gelbooru 0.2.5)
  modern,

  /// safety:safe / sketchy / unsafe
  szurubooru,

  /// plain rating tags (Derpibooru, Furbooru, ...)
  booruOnRails,

  /// rating can't be expressed in the query
  none;

  String tagOf(BooruRating rating) {
    return switch (this) {
      RatingDialect.legacy => switch (rating) {
        BooruRating.safe => 'rating:safe',
        BooruRating.sensitive ||
        BooruRating.questionable => 'rating:questionable',
        BooruRating.explicit => 'rating:explicit',
        BooruRating.all => '',
      },
      RatingDialect.modern => switch (rating) {
        BooruRating.safe => 'rating:general',
        BooruRating.sensitive => 'rating:sensitive',
        BooruRating.questionable => 'rating:questionable',
        BooruRating.explicit => 'rating:explicit',
        BooruRating.all => '',
      },
      RatingDialect.szurubooru => switch (rating) {
        BooruRating.safe => 'safety:safe',
        BooruRating.sensitive || BooruRating.questionable => 'safety:sketchy',
        BooruRating.explicit => 'safety:unsafe',
        BooruRating.all => '',
      },
      RatingDialect.none => '',
      RatingDialect.booruOnRails => switch (rating) {
        BooruRating.safe => 'safe',
        BooruRating.sensitive => 'suggestive',
        BooruRating.questionable => 'questionable',
        BooruRating.explicit => 'explicit',
        BooruRating.all => '',
      },
    };
  }
}
