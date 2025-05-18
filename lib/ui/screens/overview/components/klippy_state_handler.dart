/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/klippy_extension.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/overview/components/common/machine_cam_base_card.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_job_handler.dart';

class KlippyStateHandler extends ConsumerWidget {
  const KlippyStateHandler({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding ${machine.logNameExtended}/PrinterCard/KlippyStateHandler');

    return AsyncGuard(
      debugLabel: '${machine.logNameExtended}/PrinterCard/ConnectionStateHandler',
      toGuard: klipperProvider(machine.uuid).selectAs((d) => true),
      childOnData: _Body(machine: machine),
      childOnLoading: PrinterCard.loading(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klippy = ref.watch(klipperProvider(machine.uuid).requireValue());

    //TODO: Do I need a klippy connected check (Do the klippy domain is connected)?

    Widget body = switch (klippy.klippyState) {
      KlipperState.ready => PrinterJobHandler(machine: machine),
      KlipperState.shutdown ||
      KlipperState.error ||
      KlipperState.unauthorized =>
        _KlippyErrorShutdownUnauthorized(machine: machine, klippy: klippy),
      KlipperState.disconnected ||
      KlipperState.initializing ||
      KlipperState.startup =>
        _KlippyStartupInitializingDisconnected(machine: machine, klippy: klippy),
    };

    if (klippy.klippyState != KlipperState.ready) {
      return MachineCamBaseCard(machine: machine, body: body);
    }

    return body;
  }
}

class _KlippyStartupInitializingDisconnected extends HookWidget {
  const _KlippyStartupInitializingDisconnected({super.key, required this.machine, required this.klippy});

  final Machine machine;

  final KlipperInstance klippy;

  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    Widget icon = switch (klippy.klippyState) {
      KlipperState.startup => Icon(Icons.rocket_launch_outlined, size: 36),
      KlipperState.initializing => RotationTransition(
          turns: animationController,
          child: Icon(Icons.settings_outlined, size: 36),
        ),
      KlipperState.disconnected => Icon(Icons.usb_off, size: 36),
      _ => Icon(Icons.error_outline, size: 36),
    };

    final themeData = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        icon,
        Gap(4),
        Text(
          'components.machine_card.klippy_state.${klippy.klippyState.name}',
          style: themeData.textTheme.titleMedium,
        ).tr(),
        if (klippy.statusMessage.isNotEmpty == true)
          Text(klippy.statusMessage, style: themeData.textTheme.bodySmall, textAlign: TextAlign.center),
        Gap(8),
        _Actions(machine: machine, klippy: klippy),
      ],
    );
  }
}

class _KlippyErrorShutdownUnauthorized extends StatelessWidget {
  const _KlippyErrorShutdownUnauthorized({super.key, required this.machine, required this.klippy});

  final Machine machine;

  final KlipperInstance klippy;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);

    Color? onColor;
    Color? bgColor;
    IconData icon;

    switch (klippy.klippyState) {
      case KlipperState.shutdown:
        onColor = themeData.extension<CustomColors>()?.warning?.darken(33);
        bgColor = themeData.extension<CustomColors>()?.warning?.lighten(50);
        icon = Icons.power_off_outlined;
        break;

      case KlipperState.unauthorized:
        onColor = themeData.colorScheme.onTertiaryContainer;
        bgColor = themeData.colorScheme.tertiaryContainer;
        icon = Icons.lock_outline;
        break;
      case KlipperState.error:
      default:
        onColor = themeData.colorScheme.onErrorContainer;
        bgColor = themeData.colorScheme.errorContainer;
        icon = Icons.warning_amber;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(8),
        Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
        Gap(8),
        Card(
          color: bgColor,
          shape: _border(context, onColor),
          margin: EdgeInsets.zero,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.all(4.0), child: Icon(icon, color: onColor)),
                Gap(8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('components.machine_card.klippy_state.${klippy.klippyState.name}'),
                        style: themeData.textTheme.bodyMedium?.copyWith(color: onColor),
                      ),
                      Text(
                        klippy.statusMessage,
                        style: themeData.textTheme.bodySmall?.copyWith(color: onColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Gap(8),
        _Actions(machine: machine, klippy: klippy),
      ],
    );
  }

  ShapeBorder _border(BuildContext context, Color? borderColor) {
    /// If this property is null then [CardTheme.shape] of [ThemeData.cardTheme]
    /// is used. If that's null then the shape will be a [RoundedRectangleBorder]
    /// with a circular corner radius of 12.0 and if [ThemeData.useMaterial3] is
    /// false, then the circular corner radius will be 4.0.

    final themeData = Theme.of(context);

    final borderSide = BorderSide(color: borderColor ?? Color(0xFF000000), width: 0.5);
    final cardShape = themeData.cardTheme.shape;
    if (cardShape case RoundedRectangleBorder()) {
      return RoundedRectangleBorder(
        borderRadius: cardShape.borderRadius,
        side: borderSide,
      );
    }

    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(themeData.useMaterial3 ? 12 : 4),
      side: borderSide,
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({super.key, required this.machine, required this.klippy});

  final Machine machine;

  final KlipperInstance klippy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _KlippyActions for ${machine.logName}');
    final buttons = <Widget>[];

    final themeData = Theme.of(context);
    switch (klippy.klippyState) {
      // StartUp -> Nix oder refresh state
      // Initializing -> Nix oder refresh state

      // Shutdown -> Restart FW, Restart Klipper
      // Error -> Restart Fw, Restart Klipper

      // UnAuth -> Edit Config or nothing

      case KlipperState.shutdown:
      case KlipperState.error:
        buttons.add(ElevatedButton.icon(
          onPressed: () => ref.read(klipperServiceProvider(machine.uuid)).restartKlipper().ignore(),
          label: Text('pages.dashboard.general.restart_klipper').tr(),
          icon: Icon(Icons.restart_alt),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.error,
            foregroundColor: themeData.colorScheme.onError,
            iconColor: themeData.colorScheme.onError,
          ),
        ));
        if (klippy.klippyConnected) {
          buttons.add(ElevatedButton.icon(
            onPressed: () => ref.read(klipperServiceProvider(machine.uuid)).restartMCUs(),
            label: Text('pages.dashboard.general.restart_mcu').tr(),
            icon: Icon(Icons.restart_alt),
            style: ElevatedButton.styleFrom(
              iconSize: 18,
              backgroundColor: themeData.extension<CustomColors>()?.warning,
              foregroundColor: themeData.extension<CustomColors>()?.onWarning,
              iconColor: themeData.extension<CustomColors>()?.onWarning,
            ),
          ));
        }
        break;
      default:
      // Do Nothing;
    }

    return Row(
      spacing: 6,
      children: [for (var button in buttons) Expanded(child: button)],
    );
  }
}
