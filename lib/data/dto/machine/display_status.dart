import 'package:freezed_annotation/freezed_annotation.dart';

part 'display_status.freezed.dart';


@freezed
class DisplayStatus with _$DisplayStatus {
  const factory DisplayStatus({
    @Default(0) double progress,
    String? message,
  }) = _DisplayStatus;
}
