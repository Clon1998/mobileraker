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
    this.actionLabel,
    this.dismissLabel,
    this.actionForegroundColor,
    this.actionBackgroundColor,
    this.barrierDismissible = true,
    this.data,
  });

  final DialogIdentifierMixin type;
  final String? title;
  final String? body;
  final String? actionLabel;
  final String? dismissLabel;
  final Color? actionForegroundColor;
  final Color? actionBackgroundColor;
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
          (identical(actionLabel, other.actionLabel) || actionLabel == other.actionLabel) &&
          (identical(dismissLabel, other.dismissLabel) || dismissLabel == other.dismissLabel) &&
          (identical(actionForegroundColor, other.actionForegroundColor) ||
              actionForegroundColor == other.actionForegroundColor) &&
          (identical(actionBackgroundColor, other.actionBackgroundColor) ||
              actionBackgroundColor == other.actionBackgroundColor) &&
          (identical(barrierDismissible, other.barrierDismissible) || barrierDismissible == other.barrierDismissible) &&
          const DeepCollectionEquality().equals(data, other.data);

  @override
  int get hashCode => Object.hash(
        type,
        title,
        body,
        actionLabel,
        dismissLabel,
        actionForegroundColor,
        actionBackgroundColor,
        barrierDismissible,
        const DeepCollectionEquality().hash(data),
      );

  @override
  String toString() {
    return 'DialogRequest{type: $type, title: $title, body: $body, actionLabel: $actionLabel, dismissLabel: $dismissLabel}';
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
    String? actionLabel,
    String? dismissLabel,
    Color? actionForegroundColor,
    Color? actionBackgroundColor,
  });

  Future<DialogResponse?> showDangerConfirm({
    String? title,
    String? body,
    String? actionLabel,
    String? dismissLabel,
  });

  Future<DialogResponse?> show(DialogRequest request);
}
