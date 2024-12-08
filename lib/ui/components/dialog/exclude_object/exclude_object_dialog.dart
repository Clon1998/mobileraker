/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/print_bed_painter.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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
                        child: _ExcludeObjectMap(),
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
                    (isConfirmed) ? const _ExcludeBtnRow() : const _DefaultBtnRow(),
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

class _DefaultBtnRow extends ConsumerWidget {
  const _DefaultBtnRow({super.key});

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

class _ExcludeBtnRow extends ConsumerWidget {
  const _ExcludeBtnRow({super.key});

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

class _ExcludeObjectMap extends ConsumerWidget {
  const _ExcludeObjectMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(printerSelectedProvider.selectAs((data) => data.configFile)).requireValue;
    final controller = ref.watch(excludeObjectControllerProvider.notifier);
    final selected = ref.watch(excludeObjectControllerProvider);
    final excludeObject = ref.watch(excludeObjectProvider).requireValue!;

    return IntrinsicHeight(
      child: Center(
        child: AspectRatio(
          aspectRatio: config.sizeX / config.sizeY,
          child: CanvasTouchDetector(
            gesturesToOverride: const [
              GestureType.onTapDown,
              GestureType.onTapUp,
            ],
            builder: (context) {
              final themeData = Theme.of(context);
              return CustomPaint(
                painter: ExcludeObjectPainter(
                  bedWidth: config.sizeX,
                  bedHeight: config.sizeY,
                  bedXOffset: config.minX,
                  bedYOffset: config.minY,
                  context: context,
                  onObjectTapped: controller.onPathTapped,
                  excludeObject: excludeObject,
                  selected: selected,
                  objectColor: themeData.colorScheme.primary,
                  excludedObjectColor: themeData.disabledColor,
                  selectedObjectColor: themeData.colorScheme.secondary,
                  backgroundColor: themeData.colorScheme.surface,
                  logoColor: themeData.colorScheme.onSurface.withOpacity(0.05),
                  gridColor: themeData.disabledColor.withOpacity(0.1),
                  axisColor: themeData.disabledColor.withOpacity(0.5),
                  originColors: (x: Colors.red, y: Colors.blue),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ExcludeObjectPainter extends PrintBedPainter {
  ExcludeObjectPainter({
    required super.bedWidth,
    required super.bedHeight,
    required super.bedXOffset,
    required super.bedYOffset,
    required this.context,
    required this.onObjectTapped,
    required this.excludeObject,
    required this.selected,
    required this.objectColor,
    required this.excludedObjectColor,
    required this.selectedObjectColor,
    required super.backgroundColor,
    required super.logoColor,
    required super.gridColor,
    required super.axisColor,
    required super.originColors,
  }) : obj = selected;

  @override
  final renderLogo = true;
  @override
  final renderGrid = true;
  @override
  final renderAxis = true;

  final BuildContext context;

  final void Function(ParsedObject obj) onObjectTapped;
  final ExcludeObject excludeObject;
  final ParsedObject? selected;

  final Color objectColor;
  final Color excludedObjectColor;
  final Color selectedObjectColor;

  ParsedObject? obj;

  @override
  void paint(Canvas canvas, Size size) {
    TouchyCanvas myCanvas = TouchyCanvas(context, canvas);
    super.paint(canvas, size);

    final objectPaint = filledPaint(objectColor);
    final excludedObjectPaint = filledPaint(excludedObjectColor);
    final selectedObjectPaint = strokePaint(selectedObjectColor, 5.0);

    bool tmp = false;
    for (ParsedObject obj in excludeObject.objects) {
      List<vec.Vector2> polygons = obj.polygons;
      if (polygons.isEmpty) continue;
      tmp = true;
      Path path = objectOutlinePath(polygons);

      if (excludeObject.excludedObjects.contains(obj.name)) {
        myCanvas.drawPath(path, excludedObjectPaint);
      } else {
        myCanvas.drawPath(path, objectPaint, onTapDown: (_) => onObjectTapped(obj));
        if (selected == obj) myCanvas.drawPath(path, selectedObjectPaint);
      }
    }
    // Restore to the canvas in UI cords
    canvas.restore();
    if (!tmp) drawNoDataText(canvas, size.width, size.height);
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

  Path objectOutlinePath(List<vec.Vector2> polygons) {
    Path path = Path();

    for (int i = 0; i < polygons.length; i++) {
      var polygon = polygons[i];
      if (i == 0) {
        path.moveTo(polygon.x, polygon.y);
      } else {
        path.lineTo(polygon.x, polygon.y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(ExcludeObjectPainter oldDelegate) {
    return oldDelegate.selected != selected;
  }
}
