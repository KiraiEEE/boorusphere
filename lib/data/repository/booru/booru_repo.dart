import 'package:boorusphere/data/repository/booru/entity/booru_error.dart';
import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/booru/utils/tag_query.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/domain/repository/imageboards_repo.dart';
import 'package:boorusphere/presentation/provider/server_data_state.dart';
import 'package:boorusphere/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

class BooruRepo implements ImageboardRepo {
  BooruRepo({
    required this.parsers,
    required this.client,
    required this.server,
    required this.serverState,
  });

  final Iterable<BooruParser> parsers;
  final Dio client;
  final ServerState serverState;

  final _opt = Options(validateStatus: (it) => it == 200);
  final _log = Logger('BooruRepo');

  @override
  final Server server;

  Future<Response> _request(String url, BooruParser parser) async {
    try {
      final res = await client.get(
        url,
        options: _opt.copyWith(headers: parser.headers),
      );
      if (_isAuthError(res.data)) throw BooruError.authRequired;
      return res;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || (code == 403 && _isAuthError(e.response?.data))) {
        throw BooruError.authRequired;
      }
      final limit = TagQuery.parseLimitError(e.response?.data);
      if (limit != null) throw _TagLimitExceeded(limit);
      rethrow;
    }
  }

  /// Tag limits learned from servers during this session
  static final _tagLimits = <String, int>{};

  int? get _tagLimit {
    final learned = _tagLimits[server.id];
    if (learned != null) return learned;
    // Moebooru silently returns nothing above 6 tags for anonymous users
    if (server.searchParserId == 'Moebooru.json' && !server.hasCredentials) {
      return 6;
    }
    return null;
  }

  static bool _isAuthError(Object? data) {
    if (data is! String || data.length > 2048) return false;
    final body = data.toLowerCase();
    return body.contains('missing authentication') ||
        body.contains('api key') && body.contains('required') ||
        body.contains('<error>') && body.contains('auth');
  }

  @override
  Future<Set<String>> getSuggestion(String word) async {
    var parser = parsers.firstWhere(
      (x) => x.id == server.suggestionParserId,
      orElse: NoParser.new,
    );

    final suggestionUrl = server.suggestionUrlsOf(word);
    final res = await _request(suggestionUrl, parser);

    if (parser.canParseSuggestion(res)) {
      _log.i('getSuggestion(${server.name}): using ${parser.id}_parser');
      return parser.parseSuggestion(server, res).toSet();
    }

    parser = parsers.firstWhere(
      (it) => it.canParseSuggestion(res),
      orElse: NoParser.new,
    );

    if (parser.id.isNotEmpty) {
      _log.i(
        'getSuggestion(${server.name}): parser resolved, now using ${parser.id}_parser',
      );
      await serverState.edit(
        server,
        server.copyWith(suggestionParserId: parser.id),
      );
    }

    return parser.parseSuggestion(server, res).toSet();
  }

  @override
  Future<Set<Post>> getPage(PageOption option, int index) async {
    final query = TagQuery.split(option.query, limit: _tagLimit);
    try {
      final posts = await _fetchPage(
        option.copyWith(query: query.server),
        index,
      );
      return query.hasLocalFilter ? posts.where(query.accepts).toSet() : posts;
    } on _TagLimitExceeded catch (e) {
      final known = _tagLimits[server.id];
      if (known != null && known <= e.limit) rethrow;
      _log.i(
        'getPage(${server.name}): tag limit is ${e.limit}, '
        'filtering the rest locally',
      );
      _tagLimits[server.id] = e.limit;
      return getPage(option, index);
    }
  }

  Future<Set<Post>> _fetchPage(PageOption option, int index) async {
    var parser = parsers.firstWhere(
      (x) => x.id == server.searchParserId,
      orElse: NoParser.new,
    );

    final searchUrl = server.searchUrlOf(option, page: index);
    final res = await _request(searchUrl, parser);

    if (parser.canParsePage(res)) {
      _log.i('getPage(${server.name}): using ${parser.id}_parser');
      return parser.parsePage(server, res).toSet();
    }

    parser = parsers.firstWhere(
      (it) => it.canParsePage(res),
      orElse: NoParser.new,
    );

    if (parser.id.isNotEmpty) {
      _log.i(
        'getPage(${server.name}): parser resolved, now using ${parser.id}_parser',
      );
      await serverState.edit(
        server,
        server.copyWith(searchParserId: parser.id),
      );
    }

    return parser.parsePage(server, res).toSet();
  }
}

class _TagLimitExceeded implements Exception {
  const _TagLimitExceeded(this.limit);

  final int limit;

  @override
  String toString() => 'Server allows up to $limit tags per search';
}
