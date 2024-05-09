/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/machine/screws_tilt_adjust/screw_tilt_result.dart';
import 'package:common/data/dto/machine/screws_tilt_adjust/screws_tilt_adjust.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'screws_tilt_adjust_dialog.freezed.dart';
part 'screws_tilt_adjust_dialog.g.dart';

class ScrewsTiltAdjustDialog extends HookConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const ScrewsTiltAdjustDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        dialogCompleterProvider.overrideWithValue(completer),
        _screwsTiltAdjustDialogControllerProvider,
        printerSelectedProvider,
      ],
      child: _BedScrewAdjustDialog(request: request),
    );
  }
}

class _BedScrewAdjustDialog extends ConsumerWidget {
  const _BedScrewAdjustDialog({super.key, required this.request});

  final DialogRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var model = ref.watch(_screwsTiltAdjustDialogControllerProvider);

    return MobilerakerDialog(
      actionText: tr('general.repeat'),
      onAction: ref.read(_screwsTiltAdjustDialogControllerProvider.notifier).onRepeatPressed,
      dismissText: MaterialLocalizations.of(context).closeButtonLabel,
      onDismiss: ref.read(_screwsTiltAdjustDialogControllerProvider.notifier).onClosePressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('dialogs.screws_tilt_adjust.title'),
            style: themeData.textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          Flexible(
            child: AnimatedSwitcher(
              switchInCurve: Curves.easeInCirc,
              switchOutCurve: Curves.easeOutExpo,
              transitionBuilder: (child, anim) => SizeAndFadeTransition(
                sizeAndFadeFactor: anim,
                child: child,
              ),
              duration: kThemeAnimationDuration,
              child: switch (model) {
                AsyncValue(isLoading: true, isReloading: false) => IntrinsicHeight(
                    child: SpinKitWave(
                      size: 33,
                      color: themeData.colorScheme.primary,
                    ),
                  ),
                AsyncData(value: var data) => _ScrewsTiltResult(model: data),
                AsyncError(error: var e) => IntrinsicHeight(
                    child: ErrorCard(
                      title: const Text('Error loading Screws Tilt Adjust data'),
                      body: Text(e.toString()),
                    ),
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrewsTiltResult extends ConsumerWidget {
  const _ScrewsTiltResult({super.key, required this.model});

  final _Model model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.e('${model.screwsTiltAdjust.results}');
    var numberFormatZ = NumberFormat('0.0###', context.locale.toStringWithSeparator());
    var numberFormatXY = NumberFormat('0.#', context.locale.toStringWithSeparator());
    var themeData = Theme.of(context);

    var config = model.config.configScrewsTiltAdjust!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: config.screws.length,
            itemBuilder: (BuildContext context, int index) {
              // ignore: avoid-unsafe-collection-methods
              var screw = config.screws[index];
              var screwData = model.screwsTiltAdjust.results.elementAtOrNull(screw.index - 1);
              if (screwData == null) return const SizedBox.shrink();

              Widget trailing = switch (screwData) {
                ScrewTiltResult(isBase: true) => Chip(
                    backgroundColor: themeData.colorScheme.primary,
                    label: Text(
                      'dialogs.screws_tilt_adjust.base',
                      style: TextStyle(color: themeData.colorScheme.onPrimary),
                    ).tr(),
                  ),
                _ => Chip(
                    backgroundColor: themeData.colorScheme.tertiary,
                    avatar: Icon(
                      screwData.adjustMinutes == 0
                          ? Icons.check
                          : screwData.sign == 'CCW'
                              ? Icons.rotate_left
                              : Icons.rotate_right,
                      color: themeData.colorScheme.onTertiary,
                    ),
                    label: Text(
                      screwData.adjust,
                      style: TextStyle(color: themeData.colorScheme.onTertiary),
                    ),
                  ),
              };

              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(beautifyName(screw.name)),
                subtitle: Text(
                  'X: ${numberFormatXY.format(screw.x)}, Y: ${numberFormatXY.format(screw.y)}, Z: ${numberFormatZ.format(screwData.z)}',
                ),
                trailing: trailing,
                // subtitle: Text(screw.adjust),
              );
            },
          ),
        ),
        Divider(),
        Text(
          'dialogs.screws_tilt_adjust.hint',
          textAlign: TextAlign.center,
          style: themeData.textTheme.bodySmall,
        ).tr(),
      ],
    );
  }
}

@riverpod
class _ScrewsTiltAdjustDialogController extends _$ScrewsTiltAdjustDialogController {
  bool _completed = false;

  @override
  Future<_Model> build() async {
    var screwsTiltAdjust = await ref.watch(printerSelectedProvider.selectAsync((data) => data.screwsTiltAdjust!));
    var config = await ref.watch(printerSelectedProvider.selectAsync((data) => data.configFile));

    // await Future.delayed(Duration(seconds: 4));

    return _Model(screwsTiltAdjust: screwsTiltAdjust, config: config);
  }

  onClosePressed() {
    _complete(DialogResponse.confirmed());
  }

  onRepeatPressed() {
    _complete(DialogResponse.confirmed());
    ref.read(printerServiceSelectedProvider).screwsTiltCalculate();
  }

  _complete(DialogResponse response) {
    if (_completed == true) return;
    _completed = true;
    ref.read(dialogCompleterProvider)(response);
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required ScrewsTiltAdjust screwsTiltAdjust,
    required ConfigFile config,
  }) = __Model;
}
