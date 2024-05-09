/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/dialog/exclude_object/exclude_objects_controller.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:touchable/touchable.dart';
import 'package:vector_math/vector_math.dart' as vec;

class ExcludeObjectDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const ExcludeObjectDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        dialogCompleter.overrideWithValue(completer),
        excludeObjectControllerProvider,
      ],
      child: const _ExcludeObjectDialog(),
    );
  }
}

class _ExcludeObjectDialog extends ConsumerWidget {
  const _ExcludeObjectDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData themeData = Theme.of(context);

    return MobilerakerDialog(
      child: FormBuilder(
        key: ref.watch(excludeObjectFormKey),
        child: ref.watch(excludeObjectProvider).when<Widget>(
              data: (ExcludeObject? data) {
                var isConfirmed = ref.watch(conirmedProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'dialogs.exclude_object.title',
                      style: themeData.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ).tr(),
                    const Divider(),
                    const Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: ExcludeObjectMap(),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: kThemeAnimationDuration,
                      switchInCurve: Curves.easeInCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => SizeTransition(
                        sizeFactor: anim,
                        child: ScaleTransition(
                          scale: anim,
                          child: FadeTransition(
                            opacity: anim,
                            child: child,
                          ),
                        ),
                      ),
                      child: (isConfirmed)
                          ? ListTile(
                              tileColor: themeData.colorScheme.errorContainer,
                              textColor: themeData.colorScheme.onErrorContainer,
                              iconColor: themeData.colorScheme.onErrorContainer,
                              leading: const Icon(
                                Icons.warning_amber_outlined,
                                size: 40,
                              ),
                              title: const Text(
                                'dialogs.exclude_object.confirm_tile_title',
                              ).tr(),
                              subtitle: const Text(
                                'dialogs.exclude_object.confirm_tile_subtitle',
                              ).tr(),
                            )
                          : const SizedBox.shrink(),
                    ),
                    FormBuilderDropdown<ParsedObject?>(
                      enabled: !isConfirmed,
                      validator: FormBuilderValidators.compose(
                        [FormBuilderValidators.required()],
                      ),
                      name: 'selected',
                      items: data!.canBeExcluded
                          .map((parsedObj) => DropdownMenuItem(
                                value: parsedObj,
                                child: Text(parsedObj.name),
                              ))
                          .toList(),
                      onChanged: ref.watch(excludeObjectControllerProvider.notifier).onSelectedObjectChanged,
                      decoration: InputDecoration(
                        labelText: 'dialogs.exclude_object.label'.tr(),
                      ),
                    ),
                    (isConfirmed) ? const ExcludeBtnRow() : const DefaultBtnRow(),
                  ],
                );
              },
              error: (e, s) => const Text('Error while loading excludeObject'),
              loading: () => FadingText('Waiting for data...'),
            ),
      ),
    );
  }
}

class DefaultBtnRow extends ConsumerWidget {
  const DefaultBtnRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: ref.watch(excludeObjectControllerProvider.notifier).closeForm,
          child: Text(tr('general.cancel')),
        ),
        TextButton(
          onPressed: ((ref.watch(excludeObjectProvider.select(
                        (data) => data.valueOrNull?.objects.length ?? 0,
                      ))) >
                      1 &&
                  ref.watch(excludeObjectControllerProvider) != null)
              ? ref.watch(excludeObjectControllerProvider.notifier).onExcludePressed
              : null,
          child: const Text('dialogs.exclude_object.exclude').tr(),
        ),
      ],
    );
  }
}

class ExcludeBtnRow extends ConsumerWidget {
  const ExcludeBtnRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData themeData = Theme.of(context);
    CustomColors? customColors = themeData.extension<CustomColors>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => ref.read(conirmedProvider.notifier).state = false,
          child: Text(MaterialLocalizations.of(context).backButtonTooltip),
        ),
        TextButton(
          onPressed: ref.watch(excludeObjectControllerProvider.notifier).onCofirmPressed,
          child: Text(
            'general.confirm',
            style: TextStyle(color: customColors?.danger),
          ).tr(),
        ),
      ],
    );
  }
}

class ExcludeObjectMap extends ConsumerWidget {
  const ExcludeObjectMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ConfigFile config = ref.watch(printerSelectedProvider.selectAs((data) => data.configFile)).requireValue;

    return IntrinsicHeight(
      child: Center(
        child: AspectRatio(
          aspectRatio: config.sizeX / config.sizeY,
          child: CanvasTouchDetector(
            gesturesToOverride: const [
              GestureType.onTapDown,
              GestureType.onTapUp,
            ],
            builder: (context) => CustomPaint(
              painter: ExcludeObjectPainter(
                context,
                ref.watch(excludeObjectControllerProvider.notifier),
                ref.watch(excludeObjectProvider).requireValue!,
                ref.watch(excludeObjectControllerProvider),
                config,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExcludeObjectPainter extends CustomPainter {
  static const double bgLineDis = 50;

  ExcludeObjectPainter(this.context,
      this.controller,
      this.excludeObject,
      this.selected,
      this.config,) : obj = selected;

  final BuildContext context;
  final ExcludeObjectController controller;
  final ExcludeObject excludeObject;
  final ParsedObject? selected;
  final ConfigFile config;

  double get _maxXBed => config.sizeX;

  double get _maxYBed => config.sizeY;

  ParsedObject? obj;

  @override
  void paint(Canvas canvas, Size size) {
    TouchyCanvas myCanvas = TouchyCanvas(context, canvas);

    Color paintBgCol, paintObjCol, paintObjExcludedCol;
    if (Theme.of(context).brightness == Brightness.dark) {
      paintObjCol = Theme.of(context).colorScheme.onSurface;

      paintBgCol = paintObjCol.darken(60);
      paintObjExcludedCol = paintObjCol.darken(35);
    } else {
      paintObjCol = Theme.of(context).colorScheme.onSurface.lighten(20);
      paintBgCol = paintObjCol.lighten(30);
      paintObjExcludedCol = paintObjCol.darken(15);
    }

    var paintBg = Paint()
      ..color = paintBgCol
      ..strokeWidth = 2;

    var paintObj = Paint()
      ..color = paintObjCol
      ..strokeWidth = 2;
    var paintObjExcluded = Paint()
      ..color = paintObjExcludedCol
      ..strokeWidth = 2;

    Paint paintSelected = Paint()
      ..color = Theme.of(context).colorScheme.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    double maxX = size.width;
    double maxY = size.height;

    drawXLines(maxX, myCanvas, maxY, paintBg);
    drawYLines(maxY, myCanvas, maxX, paintBg);

    bool tmp = false;
    for (ParsedObject obj in excludeObject.objects) {
      List<vec.Vector2> polygons = obj.polygons;
      if (polygons.isEmpty) continue;
      tmp = true;
      Path path = constructPath(polygons, maxX, maxY);

      if (excludeObject.excludedObjects.contains(obj.name)) {
        myCanvas.drawPath(path, paintObjExcluded);
      } else {
        myCanvas.drawPath(
          path,
          paintObj,
          onTapDown: (x) => controller.onPathTapped(obj),
        );
        if (selected == obj) myCanvas.drawPath(path, paintSelected);
      }
    }
    if (!tmp) drawNoDataText(canvas, maxX, maxY);
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

  void drawYLines(
    double maxY,
    TouchyCanvas myCanvas,
    double maxX,
    Paint paintBg,
  ) {
    for (int i = 1; i < _maxYBed ~/ bgLineDis; i++) {
      var y = (bgLineDis * i) / _maxYBed * maxY;
      myCanvas.drawLine(Offset(0, y), Offset(maxX, y), paintBg);
    }
  }

  void drawXLines(
    double maxX,
    TouchyCanvas myCanvas,
    double maxY,
    Paint paintBg,
  ) {
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
