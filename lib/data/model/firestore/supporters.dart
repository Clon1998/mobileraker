import 'package:freezed_annotation/freezed_annotation.dart';

part 'supporters.freezed.dart';
part 'supporters.g.dart';

@freezed
class Supporter with _$Supporter {
  const factory Supporter(
      {required String fcmToken, DateTime? expirationDate}) = _Supporter;

  factory Supporter.fromJson(Map<String, dynamic> json) =>
      _$SupporterFromJson(json);
}
