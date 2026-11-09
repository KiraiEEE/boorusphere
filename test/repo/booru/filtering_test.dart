import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/data/repository/booru/utils/tag_query.dart';
import 'package:boorusphere/data/repository/server/entity/server.dart';
import 'package:boorusphere/data/repository/tags_blocker/blacklist.dart';
import 'package:boorusphere/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:flutter_test/flutter_test.dart';

const _post = Post(
  id: 1,
  tags: ['cat_ears', 'Animated', 'solo'],
  rateValue: 'e',
  score: -3,
);

Blacklist _compile(List<String> rules, {String serverId = ''}) {
  return Blacklist.compile(
    rules.map((it) => BooruTag(name: it)),
    serverId: serverId,
  );
}

void main() {
  group('blacklist', () {
    test('exact tag, case-insensitive', () {
      expect(_compile(['animated']).matches(_post), true);
      expect(_compile(['dog']).matches(_post), false);
    });

    test('wildcard', () {
      expect(_compile(['cat*']).matches(_post), true);
      expect(_compile(['*ears']).matches(_post), true);
      expect(_compile(['dog*']).matches(_post), false);
    });

    test('AND and negation', () {
      expect(_compile(['animated solo']).matches(_post), true);
      expect(_compile(['animated sound']).matches(_post), false);
      expect(_compile(['animated -sound']).matches(_post), true);
      expect(_compile(['animated -solo']).matches(_post), false);
      // a rule made only of negations would hide everything, so it's ignored
      expect(_compile(['-solo']).isEmpty, true);
    });

    test('metatags', () {
      expect(_compile(['rating:e']).matches(_post), true);
      expect(_compile(['rating:explicit']).matches(_post), true);
      expect(_compile(['rating:s']).matches(_post), false);
      expect(_compile(['score:<0']).matches(_post), true);
      expect(_compile(['score:>=0']).matches(_post), false);
    });

    test('server scope', () {
      final tags = [const BooruTag(serverId: 'a', name: 'solo')];
      expect(Blacklist.compile(tags, serverId: 'a').matches(_post), true);
      expect(Blacklist.compile(tags, serverId: 'b').matches(_post), false);
    });

    test('blocksTag only considers single-term rules', () {
      final list = _compile(['gore', 'cat*', 'animated -sound']);
      expect(list.blocksTag('gore'), true);
      expect(list.blocksTag('cat_tail'), true);
      expect(list.blocksTag('animated'), false);
    });

    test('splitInput', () {
      expect(Blacklist.splitInput('gore,  animated   -sound\nrating:e ,'), [
        'gore',
        'animated -sound',
        'rating:e',
      ]);
    });
  });

  group('tag query', () {
    test('no limit keeps everything server-side', () {
      final q = TagQuery.split('a b c');
      expect(q.server, 'a b c');
      expect(q.hasLocalFilter, false);
    });

    test('limit moves extra tags to the local filter', () {
      final q = TagQuery.split('cat_ears -dog solo rating:general', limit: 2);
      expect(q.server, 'cat_ears solo rating:general');
      expect(q.hasLocalFilter, true);
      expect(q.accepts(_post), true);
      expect(
        q.accepts(_post.copyWith(tags: ['cat_ears', 'solo', 'dog'])),
        false,
      );
    });

    test('parse danbooru tag limit error', () {
      expect(
        TagQuery.parseLimitError({
          'success': false,
          'error': 'PostQuery::TagLimitError',
          'message': 'You cannot search for more than 2 tags at a time.',
        }),
        2,
      );
      expect(TagQuery.parseLimitError('{"error": "something else"}'), null);
    });
  });

  group('rating', () {
    test('parse vocabularies', () {
      expect(BooruRating.parse('g'), BooruRating.safe);
      expect(BooruRating.parse('general'), BooruRating.safe);
      expect(BooruRating.parse('s'), BooruRating.safe);
      expect(BooruRating.parse('sensitive'), BooruRating.sensitive);
      expect(BooruRating.parse('e'), BooruRating.explicit);
      expect(BooruRating.parse('unsafe'), BooruRating.explicit);
      expect(BooruRating.parse(''), BooruRating.questionable);
    });

    test('dialect per server', () {
      const danbooru = Server(
        homepage: 'https://danbooru.donmai.us',
        searchUrl: 'posts.json?tags={tags}&page={page-id}&limit={post-limit}',
        searchParserId: 'Danbooru.json',
      );
      const e621 = Server(
        homepage: 'https://e621.net',
        searchUrl: 'posts.json?tags={tags}&page={page-id}&limit={post-limit}',
        searchParserId: 'E621.json',
      );
      const option = PageOption(query: 'cat');
      expect(
        danbooru.searchUrlOf(option, page: 1),
        contains('rating%3Ageneral'),
      );
      expect(e621.searchUrlOf(option, page: 1), contains('rating%3Asafe'));
      expect(
        danbooru.searchUrlOf(
          option.copyWith(searchRating: BooruRating.all),
          page: 1,
        ),
        isNot(contains('rating')),
      );
    });
  });

  group('server', () {
    test('uses api address and appends credentials', () {
      const rule34 = Server(
        homepage: 'https://rule34.xxx',
        apiAddr: 'https://api.rule34.xxx',
        searchUrl:
            'index.php?page=dapi&s=post&q=index&tags={tags}&pid={page-id}&limit={post-limit}',
        login: '42',
        apiKey: 'secret',
      );
      final url = rule34.searchUrlOf(const PageOption(), page: 0);
      expect(url, startsWith('https://api.rule34.xxx/index.php'));
      expect(url, endsWith('&api_key=secret&user_id=42'));

      const danbooru = Server(
        homepage: 'https://danbooru.donmai.us',
        searchUrl: 'posts.json?tags={tags}&page={page-id}&limit={post-limit}',
        login: 'me',
        apiKey: 'k',
      );
      expect(
        danbooru.searchUrlOf(const PageOption(), page: 1),
        endsWith('&login=me&api_key=k'),
      );
    });
  });
}
