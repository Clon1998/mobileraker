/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/adaptive_draggable_scrollable_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ColorPickerSheet extends StatelessWidget {
  const ColorPickerSheet({super.key, required this.initialColor});

  final String? initialColor;

  @override
  Widget build(BuildContext context) {
    return AdaptiveDraggableScrollableSheet(
      builder: (BuildContext context, ScrollController scrollController) {
        return _Sheet(scrollController: scrollController, initialColor: initialColor);
      },
    );
  }
}

class _Sheet extends HookConsumerWidget {
  const _Sheet({super.key, required this.scrollController, this.initialColor});

  final ScrollController scrollController;
  final String? initialColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final ValueNotifier<Color> hex = useValueNotifier(initialColor?.toColor() ?? Colors.orange);
    // 104ac5F

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(16),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16) + EdgeInsets.only(bottom: padding.bottom, top: 8),
            shrinkWrap: true,
            controller: scrollController,
            children: [
              ColorPicker(
                pickerColor: initialColor?.toColor() ?? Colors.orange,
                onColorChanged: (color) => hex.value = color,
                // colorPickerWidth: 300,
                hexInputBar: true,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hsl,
                pickerAreaHeightPercent: 1.0,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, BottomSheetResult.confirmed(colorToHex(hex.value, enableAlpha: false)));
            },
            child: Text(MaterialLocalizations.of(context).keyboardKeySelect),
          ),
        ),
      ],
    );
  }
}
