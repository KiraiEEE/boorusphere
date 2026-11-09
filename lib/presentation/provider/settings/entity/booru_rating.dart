import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

part 'booru_rating.g.dart';

@HiveType(typeId: 7, adapterName: 'BooruRatingAdapter')
enum BooruRating {
  @HiveField(0)
  all,
  @HiveField(1)
  safe,
  @HiveField(2)
  questionable,
  @HiveField(4)
  sensitive,
  @HiveField(3)
  explicit;

  String describe(BuildContext context) {
    switch (this) {
      case BooruRating.safe:
        return context.t.rating.safe;
      case BooruRating.questionable:
        return context.t.rating.questionable;
      case BooruRating.explicit:
        return context.t.rating.explicit;
      case BooruRating.sensitive:
        return context.t.rating.sensitive;
      default:
        return '';
    }
  }

  bool get isExplicit => this == BooruRating.explicit;

  /// Anything that is not guaranteed to be safe for work
  bool get isNsfw => this != BooruRating.safe;

  /// Parse rating metadata from various booru vocabularies.
  ///
  /// Unknown values are treated as questionable so they never leak into
  /// safe-mode results.
  static BooruRating parse(String metadata) {
    switch (metadata.trim().toLowerCase()) {
      case 'g':
      case 'general':
      case 's':
      case 'safe':
        return BooruRating.safe;
      case 'sensitive':
      case 'suggestive':
        return BooruRating.sensitive;
      case 'e':
      case 'explicit':
      case 'unsafe':
        return BooruRating.explicit;
      default:
        return BooruRating.questionable;
    }
  }

  static BooruRating fromName(String name) {
    return BooruRating.values
        .firstWhere((it) => it.name == name, orElse: () => BooruRating.safe);
  }
}
