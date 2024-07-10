/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/ui/components/mobileraker_icon_button.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';

class RangeEditSlider extends HookWidget {
  const RangeEditSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.lowerLimit = 0,
    this.upperLimit = 100,
    this.decimalPlaces = 0,
  });

  final num value;
  final num lowerLimit;
  final num upperLimit;
  final int decimalPlaces;
  final void Function(num)? onChanged;

  @override
  Widget build(BuildContext context) {
    final numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: decimalPlaces);

    final themeData = Theme.of(context);
    final SliderThemeData defaults = themeData.useMaterial3 ? _SliderDefaultsM3(context) : _SliderDefaultsM2(context);

    final enabled = onChanged != null;

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              MobilerakerIconButton(
                onPressed: () {
                  onChanged!(max(lowerLimit, value - 1));
                }.unless(onChanged == null),
                onLongPressed: () {
                  onChanged!(lowerLimit);
                }.unless(onChanged == null),
                icon: const Icon(Icons.remove),
              ),
              const Spacer(),
              Text(numberFormat.format(value)),
              const Spacer(),
              MobilerakerIconButton(
                onPressed: () {
                  num t = value + 1;
                  if (t > (upperLimit)) {
                    t = upperLimit;
                  }
                  onChanged!(t);
                }.unless(onChanged == null),
                onLongPressed: () {
                  onChanged!(upperLimit);
                }.unless(onChanged == null),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        LinearGauge(
          start: lowerLimit.toDouble(),
          end: upperLimit.toDouble(),
          customLabels: [
            CustomRulerLabel(text: numberFormat.format(lowerLimit), value: lowerLimit.toDouble()),
            CustomRulerLabel(text: numberFormat.format(upperLimit), value: upperLimit.toDouble()),
          ],
          valueBar: [
            ValueBar(
              enableAnimation: false,
              valueBarThickness: 6.0,
              value: value.toDouble(),
              color: enabled ? defaults.activeTrackColor! : defaults.disabledActiveTrackColor!,
              borderRadius: 5,
            ),
          ],
          pointers: [
            Pointer(
              value: value.toDouble(),
              shape: PointerShape.circle,
              color: enabled ? defaults.thumbColor! : defaults.disabledThumbColor!,
              isInteractive: true,
              enableAnimation: false,
              height: 25,
              // width: 10,
              pointerAlignment: PointerAlignment.center,
              onChanged: onChanged,
            ),
          ],
          linearGaugeBoxDecoration: LinearGaugeBoxDecoration(
            thickness: 5,
            backgroundColor: enabled ? defaults.inactiveTrackColor! : defaults.disabledInactiveTrackColor!,
            borderRadius: 5,
          ),
          rulers: RulerStyle(
            rulerPosition: RulerPosition.center,
            showPrimaryRulers: false,
            showSecondaryRulers: false,
            showLabel: true,
            labelOffset: 5,
            textStyle: themeData.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// Taken from Slider Class
class _SliderDefaultsM2 extends SliderThemeData {
  _SliderDefaultsM2(this.context)
      : _colors = Theme.of(context).colorScheme,
        super(trackHeight: 4.0);

  final BuildContext context;
  final ColorScheme _colors;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.primary.withOpacity(0.24);

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.32);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(0.54);

  @override
  Color? get inactiveTickMarkColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onPrimary.withOpacity(0.12);

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => Color.alphaBlend(_colors.onSurface.withOpacity(.38), _colors.surface);

  @override
  Color? get overlayColor => _colors.primary.withOpacity(0.12);

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(context).textTheme.bodyLarge!.copyWith(
        color: _colors.onPrimary,
      );

  @override
  SliderComponentShape? get valueIndicatorShape => const RectangularSliderValueIndicatorShape();
}

// BEGIN GENERATED TOKEN PROPERTIES - Slider

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 4.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.surfaceContainerHighest;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(0.38);

  @override
  Color? get inactiveTickMarkColor => _colors.onSurfaceVariant.withOpacity(0.38);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => Color.alphaBlend(_colors.onSurface.withOpacity(0.38), _colors.surface);

  @override
  Color? get overlayColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.dragged)) {
          return _colors.primary.withOpacity(0.1);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.primary.withOpacity(0.1);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(context).textTheme.labelMedium!.copyWith(
        color: _colors.onPrimary,
      );

  @override
  SliderComponentShape? get valueIndicatorShape => const DropSliderValueIndicatorShape();
}

// END GENERATED TOKEN PROPERTIES - Slider
