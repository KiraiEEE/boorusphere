import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'page_data.freezed.dart';

@freezed
abstract class PageData with _$PageData {
  const factory PageData({
    @Default(PageOption(clear: true)) PageOption option,
    // Posts that are visible after blacklist and content filtering
    @Default(<Post>[]) List<Post> posts,
    // How many fetched posts are hidden by blacklist or safe mode
    @Default(0) int hidden,
  }) = _PageData;
}
