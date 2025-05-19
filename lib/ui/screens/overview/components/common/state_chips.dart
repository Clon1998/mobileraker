/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: prefer-single-widget-per-file

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/client_state_extension.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class PrintStateChip extends HookWidget {
  const PrintStateChip({super.key, required this.printState});

  final PrintState printState;

  @override
  Widget build(BuildContext context) {
    AnimationController animationController = useAnimationController(
      duration: const Duration(seconds: 1),
    )..repeat();

    Widget? avatar = switch (printState) {
      PrintState.printing => RotationTransition(
          turns: animationController,
          child: Icon(Icons.autorenew),
        ),
      PrintState.error => Icon(Icons.warning_amber),
      PrintState.paused => Icon(Icons.pause_outlined),
      PrintState.complete => Icon(Icons.done),
      PrintState.cancelled => Icon(Icons.do_not_disturb_on_outlined),
      _ => null
    };

    return Chip(
      avatar: avatar,
      label: Text(printState.displayName),
      labelPadding: EdgeInsets.only(right: 4, left: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ClientStateChip extends HookWidget {
  const ClientStateChip({super.key, required this.state});

  final ClientState state;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    AnimationController animationController = useAnimationController(
      duration: const Duration(seconds: 1),
    )..repeat();

    var customColors = themeData.extension<CustomColors>();
    Color? fg;
    Color? bg;
    String suffix = '';
    Widget? avatar;
    switch (state) {
      case ClientState.connecting:
        avatar = RotationTransition(
          turns: animationController,
          child: Icon(Icons.autorenew),
        );
        suffix = '…';
        fg = customColors?.info;
        bg = fg?.lighten(36);
        break;
      case ClientState.connected:
        avatar = Icon(Icons.wifi);
        fg = customColors?.success;
        bg = fg?.lighten(40);
        break;
      case ClientState.disconnected:
        avatar = Icon(Icons.wifi_off);
        fg = themeData.colorScheme.onSurface;
        bg = themeData.colorScheme.surfaceContainerHigh;
        break;
      case ClientState.error:
        avatar = Icon(Icons.warning_amber);
        final isLight = themeData.brightness == Brightness.light;

        fg = isLight ? themeData.colorScheme.error : themeData.colorScheme.error.darken(30);
        bg = isLight ? themeData.colorScheme.errorContainer : themeData.colorScheme.error.lighten(20);
        break;
    }

    return Chip(
      elevation: 0,
      avatar: avatar,
      backgroundColor: bg,
      iconTheme: IconThemeData(color: fg),
      label: Text(state.displayName + suffix, style: TextStyle(color: fg)),
      labelPadding: EdgeInsets.only(right: 4, left: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
