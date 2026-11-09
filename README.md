<div align="center">
    <div><img src="assets/icons/exported/legacy-circle.png" alt="boorusphere icon" height="92"></div>
    <div><h1 align="center">Boorusphere</h1></div>
    <div>Simple, content-focused booru viewer for Android and Windows</div>
    <br/>
    <div>
        <a href="https://github.com/KiraiEEE/boorusphere/releases/latest">
            <img alt="Latest release" src="https://img.shields.io/github/v/release/KiraiEEE/boorusphere?style=for-the-badge&logo=pkgsrc&logoColor=ebebf0&labelColor=23232F&color=95b6ff">
        </a>
        <a href="https://github.com/KiraiEEE/boorusphere/actions">
            <img alt="Workflow status" src="https://img.shields.io/github/actions/workflow/status/KiraiEEE/boorusphere/ci.yml?style=for-the-badge&logo=githubactions&logoColor=ebebf0&labelColor=23232F&label=CI">
        </a>
        <a href="https://github.com/KiraiEEE/boorusphere/blob/main/LICENSE.md">
            <img alt="License" src="https://img.shields.io/github/license/KiraiEEE/boorusphere?style=for-the-badge&logo=gitbook&logoColor=ebebf0&color=b0a8f7&labelColor=23232F"/>
        </a>
    </div>
</div>

> This is a maintained continuation of [nullxception/boorusphere](https://github.com/nullxception/boorusphere), which was archived in July 2024.

# Features

- Clean Material 3 interface with frosted glass surfaces
- Android (10+) and Windows
- Works with Danbooru, Gelbooru, Moebooru, e621, Booru-on-Rails, Shimmie and Szurubooru based sites
- Plays videos and animated images (GIF, WEBM, MP4)
- One-tap NSFW switch; safe mode filters on the server and on the device
- Hide AI-generated content with one switch
- Latest / Popular / Random sorting
- Blacklist with wildcards, tag combos, exclusions and rating/score rules
- Tag suggestions, search history and favorites
- Downloads with original or sample quality
- No account needed for any bundled server; API keys can still be added for sites that require them (e.g. Gelbooru)
- Backup and restore

## Bundled servers

| Server | Engine | Notes |
| --- | --- | --- |
| Safebooru, TBIB | Gelbooru 0.2 | |
| Danbooru, AIBooru | Danbooru | Anonymous users can search up to 2 tags (4 on AIBooru); extra tags are filtered on the device |
| Konachan, Yande.re, Sakugabooru | Moebooru | |
| Wallhaven | Wallhaven | High resolution wallpapers |
| e926 | e621 | |
| Derpibooru, Furbooru | Booru-on-Rails | |
| Konachan.com, e621, Xbooru, Hypnohub | various | Adult only, hidden while NSFW is off |
| Rule34 (paheal) | Shimmie | Adult only |

Any other compatible site can be added from **Servers > Add new server**; the app detects its API automatically.

# Preview

<p align="justify">
    <img width="24%" src="fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" />
    <img width="24%" src="fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" />
    <img width="24%" src="fastlane/metadata/android/en-US/images/phoneScreenshots/3.png" />
    <img width="24%" src="fastlane/metadata/android/en-US/images/phoneScreenshots/4.png" />
</p>

# Blacklist syntax

Each line (or comma separated entry) is one rule. A post is hidden when it matches every term of any rule.

| Rule | Hides |
| --- | --- |
| `gore` | posts tagged `gore` |
| `futa*` | posts with any tag starting with `futa` |
| `animated sound` | posts tagged both `animated` and `sound` |
| `animated -sound` | animated posts without sound |
| `rating:e` | explicit posts (`s`, `q`, `e`, `sensitive`) |
| `score:<0` | posts with a negative score (`<`, `<=`, `>`, `>=`) |

Rules can apply to every server or to a single one.

# Building from source

Requires the [Flutter SDK](https://flutter.dev/) 3.44 or newer. Android builds need Android SDK platform 37; Windows builds need Visual Studio 2022 with the "Desktop development with C++" workload.

```bash
git clone https://github.com/KiraiEEE/boorusphere.git
cd boorusphere
flutter pub get
dart run slang                 # generate translations
dart run build_runner build    # generate code (freezed, riverpod, hive, routes)
flutter run
```

Release builds:

```bash
flutter build apk --release --split-per-abi
flutter build windows --release
```

### Tests

```bash
flutter test                        # unit tests
LIVE=1 flutter test test/live       # check every bundled server against the real APIs
```

### Tips

- Re-run `build_runner` after editing entities, providers or routes.
- Re-run `slang` after editing translation files (`i18n/*.i18n.json`).

# Translation

English (`i18n/en.i18n.json`) is the base language; untranslated strings fall back to it.

- Find missing strings: `dart run slang analyze --outdir=i18n`, then translate them in `i18n/_missing_translations.json`
- Apply them: `dart run slang apply --outdir=i18n`
- New language: copy `i18n/en.i18n.json` to `i18n/<language-code>.i18n.json` and run `dart run slang`

# License

[BSD-3-Clause](LICENSE.md)
