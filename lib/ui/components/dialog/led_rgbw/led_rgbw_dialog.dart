/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/led_rgbw/led_rgbw_dialog_controller.dart';

class LedRGBWDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const LedRGBWDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        dialogCompleterProvider.overrideWithValue(completer),
        dialogArgsProvider.overrideWithValue(request.data as LedRGBWDialogArgument),
        settingServiceProvider,
        ledRGBWDialogControllerProvider,
      ],
      child: const _LedRGBWDialog(),
    );
  }
}

class _LedRGBWDialog extends HookConsumerWidget {
  const _LedRGBWDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LedRGBWDialogState ledRGBWDialogState =
        ref.watch(ledRGBWDialogControllerProvider);

    var controller = ref.watch(ledRGBWDialogControllerProvider.notifier);

    var themeData = Theme.of(context);
    return MobilerakerDialog(
      actionText: tr('general.confirm'),
      onAction: controller.onSubmit,
      dismissText: MaterialLocalizations.of(context).cancelButtonLabel,
      onDismiss: controller.onCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: [
          Text(
            '${tr('general.edit')} ${beautifyName(ledRGBWDialogState.ledConfig.name)}',
            style: themeData.textTheme.headlineSmall,
          ),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                HueRingPicker(
                  hueRingStrokeWidth: 30,
                  pickerColor: ledRGBWDialogState.selectedColor,
                  onColorChanged: ref.watch(ledRGBWDialogControllerProvider.notifier).onColorChange,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${tr('dialogs.rgbw.recent_colors')}:',
                    style: themeData.textTheme.labelLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: ledRGBWDialogState.recentColors
                          .map((col) => _ColorIndicator(
                                color: col,
                                onTap: ref.watch(ledRGBWDialogControllerProvider.notifier).onColorChange,
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class _ColorIndicator extends StatelessWidget {
  const _ColorIndicator({
    super.key,
    required this.color,
    required this.onTap,
  });

  final Color color;
  final Function(Color) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ColorIndicator(HSVColor.fromColor(color)),
      ),
    );
  }
}
