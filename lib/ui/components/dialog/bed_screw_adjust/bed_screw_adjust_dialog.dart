/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/bed_screw_adjust/bed_screw_adjust_dialog_controller.dart';
import 'package:vector_math/vector_math.dart' as vec;

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
    var data = ref.watch(bedScrewAdjustDialogControllerProvider).requireValue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dialogs.bed_screw_adjust.xy_plane',
          style: Theme.of(context).textTheme.titleMedium,
        ).tr(),
        Flexible(
          child: IntrinsicHeight(
            child: Center(
              child: AspectRatio(
                aspectRatio: data.config.sizeX / data.config.sizeY,
                child: CustomPaint(
                  painter: BedScrewIndicatorPainter(
                    context,
                    data.bedScrew.currentScrew,
                    data.config,
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

class BedScrewIndicatorPainter extends CustomPainter {
  static const double bgLineDis = 50;

  const BedScrewIndicatorPainter(this.context, this.activeScrew, this.config);

  final BuildContext context;
  final int activeScrew;
  final ConfigFile config;

  double get _maxXBed => config.sizeX;

  double get _maxYBed => config.sizeY;

  @override
  void paint(Canvas canvas, Size size) {
    Color colorBG, colorScrew;
    var themeData = Theme.of(context);
    if (themeData.brightness == Brightness.dark) {
      colorScrew = themeData.colorScheme.onSurface;
      colorBG = colorScrew.darken(60);
    } else {
      colorScrew = themeData.colorScheme.onSurface.lighten(20);
      colorBG = colorScrew.lighten(30);
    }

    var paintBg = Paint()
      ..color = colorBG
      ..strokeWidth = 2;

    var paintScrew = Paint()
      ..color = colorScrew
      ..strokeWidth = 2;
    var paintSelectedScrew = Paint()
      ..color = themeData.colorScheme.secondary
      ..strokeWidth = 10.0;

    // Paint paintSelected = Paint()
    //   ..color = Theme.of(context).colorScheme.secondary
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 5.0;

    double maxX = size.width;
    double maxY = size.height;

    drawXLines(maxX, canvas, maxY, paintBg);
    drawYLines(maxY, canvas, maxX, paintBg);
    // drawOrientationText('FRONT', Alignment.bottomCenter, canvas, maxX, maxY);

    if (config.configBedScrews == null) {
      drawNoDataText(canvas, maxX, maxY);
      return;
    }
    config.configBedScrews!.screws.forEachIndexed((index, screw) {
      canvas.drawCircle(
        Offset(
          screw.x / _maxXBed * maxX,
          correctY(screw.y) / _maxYBed * maxY,
        ),
        (index == activeScrew) ? 12 : 8,
        (index == activeScrew) ? paintSelectedScrew : paintScrew,
      );
    });
  }

  void drawOrientationText(
    String text,
    Canvas canvas,
    double maxX,
    double maxY,
  ) {
    var themeData = Theme.of(context);
    TextSpan span = TextSpan(
      text: text,
      style: themeData.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w900,
        backgroundColor: themeData.colorScheme.surface,
      ),
    );
    TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(minWidth: 0, maxWidth: maxX);

    Offset offset = Offset((maxX - tp.width) / 2, (maxY - tp.height));

    tp.paint(canvas, offset);
  }

  void drawNoDataText(Canvas canvas, double maxX, double maxY) {
    TextSpan span = TextSpan(
      text: 'dialogs.exclude_object.no_visualization'.tr(),
      style: Theme.of(context).textTheme.headlineMedium,
    );
    TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(minWidth: 0, maxWidth: maxX);
    tp.paint(canvas, Offset((maxX - tp.width) / 2, (maxY - tp.height) / 2));
  }

  void drawYLines(double maxY, Canvas myCanvas, double maxX, Paint paintBg) {
    for (int i = 1; i < _maxYBed ~/ bgLineDis; i++) {
      var y = (bgLineDis * i) / _maxYBed * maxY;
      myCanvas.drawLine(Offset(0, y), Offset(maxX, y), paintBg);
    }
  }

  void drawXLines(double maxX, Canvas myCanvas, double maxY, Paint paintBg) {
    for (int i = 1; i < _maxXBed ~/ bgLineDis; i++) {
      var x = (bgLineDis * i) / _maxXBed * maxX;
      myCanvas.drawLine(Offset(x, 0), Offset(x, maxY), paintBg);
    }
  }

  double correctY(double y) => _maxYBed - y;

  Path constructPath(List<vec.Vector2> polygons, double maxX, double maxY) {
    var path = Path();
    vec.Vector2 start = polygons.first;
    path.moveTo(start.x / _maxXBed * maxX, correctY(start.y) / _maxYBed * maxY);
    for (vec.Vector2 poly in polygons) {
      path.lineTo(poly.x / _maxXBed * maxX, correctY(poly.y) / _maxYBed * maxY);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
