import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/dialog/led_rgbw/led_rgbw_dialog_controller.dart';
import 'package:mobileraker/util/misc.dart';

class LedRGBWDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const LedRGBWDialog(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(overrides: [
      dialogCompleterProvider.overrideWithValue(completer),
      dialogArgsProvider
          .overrideWithValue(request.data as LedRGBWDialogArgument),
      settingServiceProvider,
      ledRGBWDialogControllerProvider
    ], child: const _LedRGBWDialog());
  }
}

class _LedRGBWDialog extends HookConsumerWidget {
  const _LedRGBWDialog({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LedRGBWDialogState ledRGBWDialogState =
        ref.watch(ledRGBWDialogControllerProvider);

    var themeData = Theme.of(context);
    return Dialog(
        child: Padding(
      padding: const EdgeInsets.all(15.0),
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
                  pickerColor: ledRGBWDialogState.selectedColor,
                  onColorChanged: ref
                      .watch(ledRGBWDialogControllerProvider.notifier)
                      .onColorChange,
                ),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Colors:',
                      style: themeData.textTheme.labelLarge,
                    )),
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
                                  onTap: ref
                                      .watch(ledRGBWDialogControllerProvider
                                          .notifier)
                                      .onColorChange,
                                ))
                            .toList()),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: ref
                    .watch(ledRGBWDialogControllerProvider.notifier)
                    .onCancel,
                child: const Text('general.cancel').tr(),
              ),
              TextButton(
                onPressed: ref
                    .watch(ledRGBWDialogControllerProvider.notifier)
                    .onSubmit,
                child: const Text('general.confirm').tr(),
              )
            ],
          )
          // const _Footer()
        ],
      ),
    ));
  }
}

class _ColorIndicator extends StatelessWidget {
  const _ColorIndicator({
    Key? key,
    required this.color,
    required this.onTap,
  }) : super(key: key);

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
