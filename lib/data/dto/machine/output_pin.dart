import 'package:freezed_annotation/freezed_annotation.dart';

part 'output_pin.freezed.dart';

@freezed
class OutputPin with _$OutputPin {
  const factory OutputPin({
    required String name,
    @Default(0.0) double value,
  }) = _OutputPin;
}
