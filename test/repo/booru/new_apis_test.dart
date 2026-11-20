import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/entity/search_sort.dart';
import 'package:boorusphere/data/repository/booru/parser/booru_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/nekosia_json_parser.dart';
import 'package:boorusphere/data/repository/booru/parser/zerochan_json_parser.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Zerochan', () {
    const server = Server(
      id: 'Zerochan',
      homepage: 'https://www.zerochan.net',
      searchParserId: 'Zerochan.json',
    );

    test('search url', () {
      expect(
        server.searchUrlOf(
          const PageOption(query: 'hatsune_miku flower', limit: 40),
          page: 1,
        ),
        'https://www.zerochan.net/hatsune%20miku,flower?json&l=40&p=2&s=id',
      );
      expect(
        server.searchUrlOf(
          const PageOption(sort: SearchSort.popular, limit: 40),
          page: 0,
        ),
        'https://www.zerochan.net/?json&l=40&p=1&s=fav&t=1',
      );
      expect(server.supportsSort(SearchSort.popular), isTrue);
      expect(server.supportsSort(SearchSort.random), isFalse);
    });

    test('reads the items out of the broken response', () {
      // the real thing: an extra brace in front and page HTML after
      const body = '''
{
{
    "items": [
        {
            "id": "3248583",
            "width": "2000",
            "height": "3805",
            "thumbnail": "https://s3.zerochan.net/240/33/21/3248583.avif",
            "source": "",
            "tag": "Hatsune Miku",
            "tags": ["Hatsune Miku", "Long Hair", "a \\"quoted\\" ] tag"]
        }
    ]
<ul id="thumbs2"><li>zerochan.net</li></ul>
}''';
      final res = Response(requestOptions: RequestOptions(), data: body);
      final parser = ZerochanJsonParser();
      expect(parser.canParsePage(res), isTrue);
      final post = parser.parsePage(server, res).single;
      expect(post.id, 3248583);
      expect(post.previewFile, 'https://s3.zerochan.net/240/33/21/3248583.jpg');
      expect(post.sampleFile, 'https://s1.zerochan.net/.600.3248583.jpg');
      expect(ZerochanJsonParser.isGuessedOriginal(post.originalFile), isTrue);
      expect(post.tags.take(2), ['hatsune_miku', 'long_hair']);
    });
  });

  test('Nekosia search url maps tags to dashes', () {
    const server = Server(
      id: 'Nekosia',
      homepage: 'https://nekosia.cat',
      apiAddr: 'https://api.nekosia.cat',
      searchParserId: 'Nekosia.json',
    );
    expect(
      server.searchUrlOf(const PageOption(query: 'animal_ears maid'), page: 3),
      'https://api.nekosia.cat/api/v1/images/random?count=20'
      '&tags=animal-ears%2Cmaid',
    );
    expect(NekosiaJsonParser().id, server.searchParserId);
  });

  test('ids from text are stable and fit in 48 bits', () {
    final a = numericIdOf('squarecalmicelandichorse');
    expect(a, numericIdOf('squarecalmicelandichorse'));
    expect(a, isNot(numericIdOf('squarecalmicelandichorsf')));
    expect(a, inInclusiveRange(0, 0xFFFFFFFFFFFF));
  });
}
