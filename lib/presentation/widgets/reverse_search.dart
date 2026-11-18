import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/utils/extensions/post.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Reverse image search engines that take an image address in the url.
/// Anime-focused ones first: they also point back to the booru posts.
enum ReverseSearchEngine {
  saucenao('SauceNAO', 'https://saucenao.com/search.php?url='),
  iqdb('IQDB', 'https://iqdb.org/?url='),
  ascii2d('ascii2d', 'https://ascii2d.net/search/url/'),
  traceMoe('trace.moe', 'https://trace.moe/?url='),
  googleLens('Google Lens', 'https://lens.google.com/uploadbyurl?url='),
  yandex('Yandex', 'https://yandex.com/images/search?rpt=imageview&url='),
  bing(
    'Bing',
    'https://www.bing.com/images/search?view=detailv2&iss=sbi&q=imgurl:',
  ),
  tineye('TinEye', 'https://tineye.com/search?url=');

  const ReverseSearchEngine(this.label, this.prefix);

  final String label;
  final String prefix;

  String urlFor(String image) => '$prefix${Uri.encodeComponent(image)}';
}

class ReverseSearchSheet extends StatelessWidget {
  const ReverseSearchSheet({super.key, required this.post});

  final Post post;

  static Future<void> show(BuildContext context, Post post) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ReverseSearchSheet(post: post),
    );
  }

  /// Engines download the picture themselves: the sample is big enough to
  /// match and less likely to be blocked than the original, videos send
  /// their thumbnail.
  String get _image {
    if (post.content.isVideo) return post.previewFile;
    if (post.sampleFile.isNotEmpty) return post.sampleFile;
    return post.originalFile;
  }

  void _open(BuildContext context, String url) {
    context.navigator.pop();
    launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.reverseSearch;
    final artists = post.tagsArtist;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(t.title, style: context.theme.textTheme.titleLarge),
            ),
            for (final engine in ReverseSearchEngine.values)
              ListTile(
                leading: Icon(
                  engine == ReverseSearchEngine.traceMoe
                      ? Icons.movie_outlined
                      : Icons.image_search_rounded,
                ),
                title: Text(engine.label),
                subtitle: switch (engine) {
                  ReverseSearchEngine.saucenao ||
                  ReverseSearchEngine.iqdb ||
                  ReverseSearchEngine.ascii2d => Text(t.boorus),
                  ReverseSearchEngine.traceMoe => Text(t.animeScene),
                  _ => null,
                },
                onTap: () => _open(context, engine.urlFor(_image)),
              ),
            // X has no image search, the artist's name is the next best thing
            for (final artist in artists.take(2))
              ListTile(
                leading: const Icon(Icons.person_search_outlined),
                title: Text(t.artistOnX(artist: artist.replaceAll('_', ' '))),
                onTap: () => _open(
                  context,
                  'https://x.com/search?f=media&q='
                  '${Uri.encodeComponent(artist.replaceAll('_', ' '))}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
