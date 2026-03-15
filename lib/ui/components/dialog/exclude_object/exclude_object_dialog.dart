/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/print_bed_painter.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:touchable/touchable.dart';
import 'package:vector_math/vector_math.dart' as vec;

class ExcludeObjectDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const ExcludeObjectDialog({super.key, required this.request, required this.completer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ExcludeObjectDialog(completer: completer);
  }
}

class _ExcludeObjectDialog extends HookConsumerWidget {
  const _ExcludeObjectDialog({super.key, required this.completer});

  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excludeObject = ref.watch(printerSelectedProvider.selectAs((data) => data.excludeObject));

    ref.listen(printerSelectedProvider, (prev, next) {
      next.whenData((state) {
        if (!const {PrintState.printing, PrintState.paused}.contains(state.print.state)) {
          if (context.mounted) completer(DialogResponse.aborted());
        }
      });
    });

    return MobilerakerDialog(
      child: AsyncValueWidget(
        skipLoadingOnReload: true,
        value: excludeObject,
        data: (data) => _Data(excludeObject: data, completer: completer),
      ),
    );
  }
}

class _Data extends HookConsumerWidget {
  const _Data({super.key, required this.excludeObject, required this.completer});

  final ExcludeObject? excludeObject;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmed = useState(false);
    final selectedObject = useState<ParsedObject?>(null);

    final themeData = Theme.of(context);
    final customColors = themeData.extension<CustomColors>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('dialogs.exclude_object.title', style: themeData.textTheme.titleLarge, textAlign: TextAlign.center).tr(),
        const Divider(),
        Flexible(
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _ExcludeObjectMap(selected: selectedObject.value, onObjectSelected: (o) => selectedObject.value = o),
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
              child: FadeTransition(opacity: anim, child: child),
            ),
          ),
          child: (confirmed.value)
              ? ListTile(
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  leading: const Icon(Icons.warning_amber_outlined, size: 40),
                  title: const Text('dialogs.exclude_object.confirm_tile_title').tr(),
                  subtitle: const Text('dialogs.exclude_object.confirm_tile_subtitle').tr(),
                )
              : const SizedBox.shrink(),
        ),
        InputDecorator(
          isEmpty: selectedObject.value == null,
          decoration: InputDecoration(labelText: 'dialogs.exclude_object.label'.tr()),
          child: DropdownButton<ParsedObject?>(
            isDense: true,
            isExpanded: true,
            underline: SizedBox.shrink(),
            value: selectedObject.value,
            onChanged: confirmed.value ? null : (obj) => selectedObject.value = obj,
            items: excludeObject!.excludableObjects
                .map((parsedObj) => DropdownMenuItem(value: parsedObj, child: Text(parsedObj.name)))
                .toList(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (confirmed.value) ...[
              TextButton(
                onPressed: () => confirmed.value = false,
                child: Text(MaterialLocalizations.of(context).backButtonTooltip),
              ),
              TextButton(
                onPressed: () {
                  if (selectedObject.value == null) return;
                  ref.read(printerServiceSelectedProvider).excludeObject(selectedObject.value!);
                  completer(DialogResponse.confirmed());
                },
                child: Text('general.confirm', style: TextStyle(color: customColors?.danger)).tr(),
              ),
            ] else ...[
              TextButton(onPressed: () => completer(DialogResponse.aborted()), child: Text(tr('general.cancel'))),
              TextButton(
                onPressed: (() => {
                  confirmed.value = true,
                }).only((excludeObject?.objects.length ?? 0) > 1 && selectedObject.value != null),
                child: const Text('dialogs.exclude_object.exclude').tr(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ExcludeObjectMap extends ConsumerWidget {
  const _ExcludeObjectMap({super.key, required this.onObjectSelected, required this.selected});

  final Function(ParsedObject obj) onObjectSelected;
  final ParsedObject? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (config, excludeObject) = ref
        .watch(printerSelectedProvider.selectAs((data) => (data.configFile, data.excludeObject!)))
        .requireValue;

    return IntrinsicHeight(
      child: Center(
        child: AspectRatio(
          aspectRatio: config.sizeX / config.sizeY,
          child: CanvasTouchDetector(
            gesturesToOverride: const [GestureType.onTapDown, GestureType.onTapUp],
            builder: (context) {
              final themeData = Theme.of(context);
              return CustomPaint(
                painter: ExcludeObjectPainter(
                  bedWidth: config.sizeX,
                  bedHeight: config.sizeY,
                  bedXOffset: config.minX,
                  bedYOffset: config.minY,
                  context: context,
                  onObjectTapped: onObjectSelected,
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
    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
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
