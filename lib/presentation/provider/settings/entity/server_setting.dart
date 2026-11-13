import 'package:boorusphere/data/repository/booru/entity/page_option.dart';
import 'package:boorusphere/data/repository/booru/entity/search_sort.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_setting.freezed.dart';

@freezed
abstract class ServerSetting with _$ServerSetting {
  const factory ServerSetting({
    @Default('') String lastActiveId,
    @Default(PageOption.defaultLimit) int postLimit,
    @Default(SearchSort.latest) SearchSort sort,
  }) = _ServerSetting;
  const ServerSetting._();
}
