/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/config_bed_screws.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/print_bed_painter.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/bed_screw_adjust/bed_screw_adjust_dialog_controller.dart';

class BedScrewAdjustDialog extends HookConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const BedScrewAdjustDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        dialogCompleterProvider.overrideWithValue(completer),
        bedScrewAdjustDialogControllerProvider,
        printerSelectedProvider,
      ],
      child: _BedScrewAdjustDialog(request: request, completer: completer),
    );
  }
}

class _BedScrewAdjustDialog extends ConsumerWidget {
  const _BedScrewAdjustDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  final DialogRequest request;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        var pop = await ref.read(bedScrewAdjustDialogControllerProvider.notifier).onPopTriggered();
        var naviator = Navigator.of(context);
        if (pop && naviator.canPop()) {
          naviator.pop();
        }
      },
      child: MobilerakerDialog(
        footer: _Footer(dialogCompleter: completer),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                request.title ?? tr('dialogs.bed_screw_adjust.title'),
                style: themeData.textTheme.headlineSmall,
              ),
            ),
            Flexible(
              child: AnimatedSwitcher(
                switchInCurve: Curves.easeInCirc,
                switchOutCurve: Curves.easeOutExpo,
                transitionBuilder: (child, anim) => SizeAndFadeTransition(
                  sizeAndFadeFactor: anim,
                  child: child,
                ),
                duration: kThemeAnimationDuration,
                child: ref.watch(bedScrewAdjustDialogControllerProvider).when(
                      data: (data) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Flexible(
                                    child: _ScrewLocationIndicator(),
                                  ),
                                  InputDecorator(
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.only(top: 8),
                                      floatingLabelBehavior: FloatingLabelBehavior.always,
                                      label: const Text(
                                        'dialogs.bed_screw_adjust.active_screw_title',
                                      ).tr(),
                                      border: InputBorder.none,
                                    ),
                                    child: Text(data.config.configBedScrews!.screws[data.bedScrew.currentScrew].name),
                                  ),
                                  InputDecorator(
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.only(top: 8),
                                      floatingLabelBehavior: FloatingLabelBehavior.always,
                                      label: const Text(
                                        'dialogs.bed_screw_adjust.accept_screw_title',
                                      ).tr(),
                                      border: InputBorder.none,
                                    ),
                                    child: const Text(
                                      'dialogs.bed_screw_adjust.accept_screw_value',
                                    ).tr(args: [
                                      data.bedScrew.acceptedScrews.toString(),
                                      data.config.configBedScrews!.screws.length.toString(),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              backgroundColor: themeData.colorScheme.primaryContainer,
                              value: data.bedScrew.acceptedScrews / data.config.configBedScrews!.screws.length,
                            ),
                          ),
                          Text(
                            'dialogs.bed_screw_adjust.hint',
                            textAlign: TextAlign.center,
                            style: themeData.textTheme.bodySmall,
                          ).tr(),
                        ],
                      ),
                      error: (e, s) => IntrinsicHeight(
                        child: ErrorCard(
                          title: const Text('Error loading Bed Screw'),
                          body: Text(e.toString()),
                        ),
                      ),
                      loading: () => IntrinsicHeight(
                        child: SpinKitWave(
                          size: 33,
                          color: themeData.colorScheme.primary,
                        ),
                      ),
                      skipLoadingOnReload: true,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({super.key, required this.dialogCompleter});

  final DialogCompleter dialogCompleter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // var controller = manualOffsetDialogControllerProvider(dialogCompleter);
    var bedScrewAndConfig = ref.watch(bedScrewAdjustDialogControllerProvider).valueOrNull;

    var themeData = Theme.of(context);

    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.end,
      overflowDirection: VerticalDirection.up,
      children: [
        TextButton(
          onPressed: ref.read(bedScrewAdjustDialogControllerProvider.notifier).onAbortPressed,
          child: const Text('general.abort').tr(),
        ),
        if (bedScrewAndConfig != null)
          OverflowBar(
            children: [
              TextButton(
                onPressed: ref.read(bedScrewAdjustDialogControllerProvider.notifier).onAdjustedPressed,
                child: const Text('dialogs.bed_screw_adjust.adjusted_btn').tr(),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: themeData.colorScheme.secondary,
                ),
                onPressed: ref.read(bedScrewAdjustDialogControllerProvider.notifier).onAcceptPressed,
                child: const Text('general.accept').tr(),
              ),
            ],
          ),
      ],
    );
  }
}

class _ScrewLocationIndicator extends ConsumerWidget {
  const _ScrewLocationIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(bedScrewAdjustDialogControllerProvider).requireValue;
    final themeData = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dialogs.bed_screw_adjust.xy_plane',
          style: themeData.textTheme.titleMedium,
        ).tr(),
        Flexible(
          child: IntrinsicHeight(
            child: Center(
              child: AspectRatio(
                aspectRatio: data.config.sizeX / data.config.sizeY,
                child: CustomPaint(
                  painter: _BedScrewIndicatorPainter(
                    // bedWidth: data.config.sizeX,
                    bedWidth: data.config.sizeX,
                    bedHeight: data.config.sizeY,
                    bedXOffset: data.config.minX,
                    bedYOffset: data.config.minY,
                    activeScrew: data.bedScrew.currentScrew,
                    bedScrews: data.config.configBedScrews!,
                    activeColor: themeData.colorScheme.secondary,
                    inactiveColor: themeData.colorScheme.onSurface,
                    backgroundColor: themeData.colorScheme.surface,
                    logoColor: themeData.colorScheme.onSurface.withOpacity(0.05),
                    gridColor: themeData.disabledColor.withOpacity(0.1),
                    axisColor: themeData.disabledColor.withOpacity(0.5),
                    originColors: (x: Colors.red, y: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BedScrewIndicatorPainter extends PrintBedPainter {
  const _BedScrewIndicatorPainter({
    required super.bedWidth,
    required super.bedHeight,
    required super.bedXOffset,
    required super.bedYOffset,
    required this.activeScrew,
    required this.bedScrews,
    required this.activeColor,
    required this.inactiveColor,
    required super.backgroundColor,
    required super.logoColor,
    required super.gridColor,
    required super.axisColor,
    required super.originColors,
  });

  @override
  final renderLogo = true;
  @override
  final renderGrid = true;
  @override
  final renderAxis = true;

  final int activeScrew;
  final ConfigBedScrews bedScrews;

  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);
    final activePaint = filledPaint(activeColor);
    final inActivePaint = filledPaint(inactiveColor);

    final diag = sqrt(bedWidth * bedWidth + bedHeight * bedHeight);
    final screwRadius = diag * 0.02;

    for (var i = 0; i < bedScrews.screws.length; i++) {
      final screw = bedScrews.screws[i];
      var isActive = i == activeScrew;
      canvas.drawCircle(
        Offset(
          screw.x,
          screw.y,
        ),
        isActive ? screwRadius * 1.25 : screwRadius,
        isActive ? activePaint : inActivePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BedScrewIndicatorPainter oldDelegate) {
    return oldDelegate.activeScrew != activeScrew;
  }
}
