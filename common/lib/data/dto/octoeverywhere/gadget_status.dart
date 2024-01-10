/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gadget_status.freezed.dart';
part 'gadget_status.g.dart';

@freezed
class GadgetStatus with _$GadgetStatus {
  @JsonSerializable(fieldRename: FieldRename.pascal)
  const factory GadgetStatus({
    required String status,
    required String statusColor,
    required int rating,
    required GadgetState state,
  }) = _GadgetStatus;

  factory GadgetStatus.fromJson(Map<String, dynamic> json) => _$GadgetStatusFromJson(json);
}

@JsonEnum(alwaysCreate: true, valueField: 'value')
enum GadgetState {
  disabled(0),
  disabledForCurrentPrint(1),
  idle(2),
  active(3),
  pausedDueToFailure(4);

  const GadgetState(this.value);

  final int value;
}
