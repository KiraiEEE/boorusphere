import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:dio/dio.dart';

abstract class BooruParser {
  const BooruParser();

  String get id;
  String get postUrl => '';
  String get suggestionQuery => '';
  String get searchQuery => '';
  Map<String, String> get headers => {};
  Iterable<BooruParserType> get type;

  /// Headers that need a request of their own first, like a login token
  Future<Map<String, String>> headersFor(Dio client) async => headers;

  /// Some APIs answer with an error status but a usable body
  bool acceptsStatus(int? code) => code == 200;

  /// [ResponseType.plain] for APIs whose JSON needs fixing before decoding
  ResponseType get responseType => ResponseType.json;

  bool canParsePage(Response res) => false;
  Iterable<Post> parsePage(Server server, Response res) => [];
  bool canParseSuggestion(Response res) => false;
  Iterable<String> parseSuggestion(Server server, Response res) => [];
}

enum BooruParserType { search, suggestion }

class NoParser extends BooruParser {
  const NoParser();

  @override
  final id = '';

  @override
  List<BooruParserType> get type => [];
}

/// Stable 48-bit number for APIs whose ids aren't numbers (FNV-1a)
int numericIdOf(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFF;
  }
  return hash;
}
