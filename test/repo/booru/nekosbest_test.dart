import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/parser/nekosbest_json_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const server = Server(
    id: 'nekos.best',
    homepage: 'https://nekos.best',
    searchUrl: 'api/v2/search?query={tags}&type=2&amount=20',
    tagSuggestionUrl: 'api/v2/endpoints?q={tag-part}',
    searchParserId: 'NekosBest.json',
    suggestionParserId: 'NekosBest.json',
  );
  final parser = NekosBestJsonParser();

  group('nekos.best search url', () {
    String urlOf(String query, [int page = 0]) =>
        server.searchUrlOf(PageOption(query: query), page: page);

    test('empty search walks through the reactions', () {
      expect(urlOf(''), 'https://nekos.best/api/v2/hug?amount=20');
      expect(urlOf('', 1), 'https://nekos.best/api/v2/pat?amount=20');
    });

    test('a reaction name gives random GIFs of it', () {
      expect(urlOf('Dance'), 'https://nekos.best/api/v2/dance?amount=20');
    });

    test('anything else searches anime titles', () {
      expect(
        urlOf('kimetsu_no yaiba'),
        'https://nekos.best/api/v2/search'
        '?query=kimetsu+no+yaiba&type=2&amount=20',
      );
    });

    test('too short for a title search falls back to reactions', () {
      expect(urlOf('ab'), 'https://nekos.best/api/v2/hug?amount=20');
    });

    test('only joins all-servers mode when it understands the query', () {
      expect(server.understandsQuery(''), isTrue);
      expect(server.understandsQuery('hug'), isTrue);
      expect(server.understandsQuery('1girl long_hair'), isFalse);
    });
  });

  test('nekos.best page', () {
    final res = Response(
      requestOptions: RequestOptions(),
      data: {
        'results': [
          {
            'anime_name': 'Inu x Boku Secret Service',
            'url':
                'https://nekos.best/api/v2/hug/e868c5a9-a440-491a-a96b-fda4953202f7.gif',
            'dimensions': {'width': 500, 'height': 281},
          },
          // duplicate
          {
            'anime_name': 'Inu x Boku Secret Service',
            'url':
                'https://nekos.best/api/v2/hug/e868c5a9-a440-491a-a96b-fda4953202f7.gif',
            'dimensions': {'width': 500, 'height': 281},
          },
          // not a gif
          {
            'anime_name': 'x',
            'url': 'https://nekos.best/api/v2/neko/abc.png',
            'dimensions': {'width': 1, 'height': 1},
          },
        ],
      },
    );

    expect(parser.canParsePage(res), isTrue);
    final posts = parser.parsePage(server, res);
    expect(posts, hasLength(1));
    final post = posts.first;
    expect(post.id, int.parse('e868c5a9a440', radix: 16));
    expect(post.tags, ['hug', 'inu_x_boku_secret_service', 'animated_gif']);
    expect(post.width, 500);
    expect(post.rateValue, 'safe');
  });

  test('nekos.best suggestions', () {
    final res = Response(
      requestOptions: RequestOptions(
        path: 'https://nekos.best/api/v2/endpoints?q=han',
      ),
      data: {
        'hug': {'format': 'gif'},
      },
    );
    expect(parser.canParseSuggestion(res), isTrue);
    expect(parser.parseSuggestion(server, res), ['handhold', 'handshake']);
  });
}
