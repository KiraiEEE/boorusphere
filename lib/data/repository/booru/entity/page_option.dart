import 'package:boorusphere/data/repository/booru/entity/search_sort.dart';
import 'package:boorusphere/presentation/provider/settings/entity/booru_rating.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'page_option.freezed.dart';

@freezed
abstract class PageOption with _$PageOption {
  const factory PageOption({
    @Default('') String query,
    @Default(false) bool clear,
    @Default(PageOption.defaultLimit) int limit,
    @Default(BooruRating.safe) BooruRating searchRating,
    @Default(SearchSort.latest) SearchSort sort,
  }) = _PageOption;
  const PageOption._();

  static const defaultLimit = 40;
}
