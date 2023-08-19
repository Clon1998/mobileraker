/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dialog_service_interface.g.dart';

mixin DialogIdentifierMixin {}

enum CommonDialogs implements DialogIdentifierMixin {
  stacktrace;
}

typedef DialogCompleter = Function(DialogResponse);

class DialogRequest<T> {
  DialogRequest({required this.type,
    this.title,
    this.body,
    this.confirmBtn,
    this.cancelBtn,
    this.confirmBtnColor,
    this.cancelBtnColor,
    this.barrierDismissible = true,
    this.data});

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
          type == other.type &&
          title == other.title &&
          body == other.body &&
          confirmBtn == other.confirmBtn &&
          cancelBtn == other.cancelBtn &&
          data == other.data;

  @override
  int get hashCode =>
      type.hashCode ^
      title.hashCode ^
      body.hashCode ^
      confirmBtn.hashCode ^
      cancelBtn.hashCode ^
      data.hashCode;

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
          confirmed == other.confirmed &&
          data == other.data;

  @override
  int get hashCode => confirmed.hashCode ^ data.hashCode;

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
