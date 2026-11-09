// Live check of every bundled server preset against the real APIs.
// Run with: LIVE=1 flutter test test/live
import 'dart:convert';
import 'dart:io';

import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/booruonrails_json_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/danbooru_json_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/e621_json_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/gelbooru_json_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/moebooru_json_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/safebooru_xml_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final enabled = Platform.environment['LIVE'] == '1';
  final parsers = <BooruParser>[
    BooruOnRailsJsonParser(),
    DanbooruJsonParser(),
    E621JsonParser(),
    GelbooruJsonParser(),
    MoebooruJsonParser(),
    SafebooruXmlParser(),
  ];
  final dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Boorusphere/2.0.0 (+https://github.com/KiraiEEE/boorusphere)',
    },
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    validateStatus: (_) => true,
  ));

  final servers = (jsonDecode(File('assets/servers.json').readAsStringSync())
          as List)
      .map((it) => Server.fromJson(it as Map<String, dynamic>));

  BooruParser parserOf(String id) => parsers.firstWhere((it) => it.id == id);

  for (final server in servers) {
    test('${server.name} search', skip: !enabled, () async {
      final url = server.searchUrlOf(
        PageOption(
          limit: 5,
          searchRating: server.nsfw ? BooruRating.all : BooruRating.safe,
        ),
        page: server.searchUrl.contains('pid=') ? 0 : 1,
      );
      final res = await dio.get(url);
      if (res.statusCode == 401 ||
          '${res.data}'.contains('Missing authentication')) {
        markTestSkipped('${server.name} requires credentials');
        return;
      }
      if (res.statusCode == 503) {
        markTestSkipped('${server.name} is down (503)');
        return;
      }
      final parser = parserOf(server.searchParserId);
      expect(parser.canParsePage(res), true, reason: url);
      final posts = parser.parsePage(server, res);
      expect(posts, isNotEmpty, reason: url);
      if (!server.nsfw) {
        expect(posts.every((it) => !BooruRating.parse(it.rateValue).isNsfw),
            true,
            reason: 'safe search returned nsfw posts: $url');
      }
    });

    test('${server.name} suggestion', skip: !enabled, () async {
      final url = server.suggestionUrlsOf('cat');
      final res = await dio.get(url);
      if (res.statusCode == 401 ||
          res.statusCode == 503 ||
          '${res.data}'.contains('Missing authentication')) {
        markTestSkipped('${server.name} unavailable (${res.statusCode})');
        return;
      }
      final parser = parserOf(server.suggestionParserId);
      expect(parser.canParseSuggestion(res), true, reason: url);
      expect(parser.parseSuggestion(server, res), isNotEmpty, reason: url);
    });
  }
}
