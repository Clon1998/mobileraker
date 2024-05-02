/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dialog_service_interface.g.dart';

mixin DialogIdentifierMixin {}

enum CommonDialogs implements DialogIdentifierMixin {
  activeMachine,
  stacktrace;
}

typedef DialogCompleter = Function(DialogResponse);

class DialogRequest<T> {
  DialogRequest({
    required this.type,
    this.title,
    this.body,
    this.confirmBtn,
    this.cancelBtn,
    this.confirmBtnColor,
    this.cancelBtnColor,
    this.barrierDismissible = true,
    this.data,
  });

  final DialogIdentifierMixin type;
  final String? title;
  final String? body;
  final String? confirmBtn;
  final String? cancelBtn;
  final Color? confirmBtnColor;
  final Color? cancelBtnColor;
  final bool barrierDismissible;
  final T? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogRequest &&
          runtimeType == other.runtimeType &&
          (identical(type, other.type) || type == other.type) &&
          (identical(title, other.title) || title == other.title) &&
          (identical(body, other.body) || body == other.body) &&
          (identical(confirmBtn, other.confirmBtn) || confirmBtn == other.confirmBtn) &&
          (identical(cancelBtn, other.cancelBtn) || cancelBtn == other.cancelBtn) &&
          (identical(confirmBtnColor, other.confirmBtnColor) || confirmBtnColor == other.confirmBtnColor) &&
          (identical(cancelBtnColor, other.cancelBtnColor) || cancelBtnColor == other.cancelBtnColor) &&
          (identical(barrierDismissible, other.barrierDismissible) || barrierDismissible == other.barrierDismissible) &&
          const DeepCollectionEquality().equals(data, other.data);

  @override
  int get hashCode => Object.hash(
        type,
        title,
        body,
        confirmBtn,
        cancelBtn,
        confirmBtnColor,
        cancelBtnColor,
        barrierDismissible,
        const DeepCollectionEquality().hash(data),
      );

  @override
  String toString() {
    return 'DialogRequest{type: $type, title: $title, body: $body, confirmBtn: $confirmBtn, cancelBtn: $cancelBtn}';
  }
}

class DialogResponse<T> {
  DialogResponse({this.confirmed = false, this.data});

  factory DialogResponse.confirmed([T? data]) {
    return DialogResponse(confirmed: true, data: data);
  }

  factory DialogResponse.aborted([T? data]) {
    return DialogResponse(confirmed: false, data: data);
  }

  final bool confirmed;
  final T? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogResponse &&
          runtimeType == other.runtimeType &&
          (identical(confirmed, other.confirmed) || confirmed == other.confirmed) &&
          const DeepCollectionEquality().equals(data, other.data);

  @override
  int get hashCode => Object.hash(
        confirmed,
        const DeepCollectionEquality().hash(data),
      );

  @override
  String toString() {
    return 'DialogResponse{confirmed: $confirmed, data: $data}';
  }
}

@Riverpod(keepAlive: true)
DialogService dialogService(DialogServiceRef ref) => throw UnimplementedError();

abstract interface class DialogService {
  bool get isDialogOpen;

  Map<DialogIdentifierMixin, Widget Function(DialogRequest, DialogCompleter)> get availableDialogs;

  Future<DialogResponse?> showConfirm({
    String? title,
    String? body,
    String? confirmBtn,
    String? cancelBtn,
    Color? confirmBtnColor,
    Color? cancelBtnColor,
  });

  Future<DialogResponse?> show(DialogRequest request);
}
