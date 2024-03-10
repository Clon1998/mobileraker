/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/fan.dart';
import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:common/data/dto/machine/fans/named_fan.dart';
import 'package:common/data/dto/machine/fans/print_fan.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/card_with_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../components/adaptive_horizontal_scroll.dart';
import '../../../components/card_with_button.dart';
import '../../../components/dialog/edit_form/num_edit_form_controller.dart';
import '../../../components/spinning_fan.dart';

part 'fans_card.freezed.dart';
part 'fans_card.g.dart';

class FansCard extends ConsumerWidget {
  const FansCard({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading =
        ref.watch(_fansCardControllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));

    if (showLoading) {
      return const _FansCardLoading();
    }
    // logger.i('Rebuilding fans card');

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardTitle(machineUUID: machineUUID),
          _CardBody(machineUUID: machineUUID),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FansCardLoading extends StatelessWidget {
  const _FansCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CardTitleSkeleton(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: CardWithSkeleton(
                          contentTextStyles: [
                            themeData.textTheme.bodySmall,
                            themeData.textTheme.headlineSmall,
                          ],
                        ),
                      ),
                      Flexible(
                        child: CardWithSkeleton(
                          contentTextStyles: [
                            themeData.textTheme.bodySmall,
                            themeData.textTheme.headlineSmall,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: SizedBox(
                      width: 30,
                      height: 11,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(_fansCardControllerProvider(machineUUID).selectRequireValue((data) => data.fans.length));

    // logger.i('Rebuilding fans card title');

    return ListTile(
      leading: const Icon(FlutterIcons.fan_mco),
      title: const Text('pages.dashboard.control.fan_card.title').plural(model),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // logger.i('Rebuilding fans card body');

    var fansCount = ref.watch(_fansCardControllerProvider(machineUUID).selectRequireValue((data) => data.fans.length));
    var hasPrintFan =
        ref.watch(_fansCardControllerProvider(machineUUID).selectRequireValue((data) => data.hasPrintFan));

    return AdaptiveHorizontalScroll(
      pageStorageKey: "fans$machineUUID",
      children: [
        // PrintFan
        if (hasPrintFan)
          _Fan(
            fanProvider: _fansCardControllerProvider(machineUUID).selectRequireValue((value) => value.printFan),
            machineUUID: machineUUID,
          ),
        // All other fans
        for (var i = 0; i < fansCount; i++)
          _Fan(
            // ignore: avoid-unsafe-collection-methods
            fanProvider: _fansCardControllerProvider(machineUUID).selectRequireValue((value) => value.fans[i]),
            machineUUID: machineUUID,
          ),
      ],
    );
  }
}

class _Fan extends ConsumerWidget {
  const _Fan({super.key, required this.fanProvider, required this.machineUUID});

  final ProviderListenable<Fan?> fanProvider;
  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fan = ref.watch(fanProvider);

    // logger.i('Rebuilding fan card for $fan');

    if (fan == null) {
      return const SizedBox.shrink();
    }

    var klippyCanReceiveCommands =
        ref.watch(_fansCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands));
    var controller = ref.watch(_fansCardControllerProvider(machineUUID).notifier);

    String name = switch (fan) {
      NamedFan(name: final n) => beautifyName(n),
      PrintFan() => 'pages.dashboard.control.fan_card.part_fan'.tr(),
      // This should never happen since either its a PrintFan or a NamedFan
      _ => "Fan",
    };

    VoidCallback? onTap = switch (fan) {
      GenericFan() when klippyCanReceiveCommands => () => controller.onEditGenericFan(fan),
      PrintFan() when klippyCanReceiveCommands => controller.onEditPartFan,
      _ => null,
    };

    return _FanCard(name: name, speed: fan.speed, onTap: onTap);
  }
}

class _FanCard extends StatelessWidget {
  static const double icoSize = 30;

  final String name;
  final double speed;
  final VoidCallback? onTap;

  const _FanCard({
    super.key,
    required this.name,
    required this.speed,
    this.onTap,
  });

  @override
  Widget build(_) {
    return CardWithButton(
      buttonChild: onTap == null
          ? const Text('pages.dashboard.control.fan_card.static_fan_btn').tr()
          : const Text('general.set').tr(),
      onTap: onTap,
      builder: (context) {
        var themeData = Theme.of(context);

        var numberFormat = NumberFormat.percentPattern(context.locale.toStringWithSeparator());

        return Tooltip(
          message: name,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: themeData.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    speed > 0 ? numberFormat.format(speed) : 'general.off'.tr(),
                    style: themeData.textTheme.headlineSmall,
                  ),
                ],
              ),
              speed > 0 ? const SpinningFan(size: icoSize) : const Icon(FlutterIcons.fan_off_mco, size: icoSize),
            ],
          ),
        );
      },
    );
  }
}

@riverpod
class _FansCardController extends _$FansCardController {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  DialogType get _dialogMode {
    return ref.read(boolSettingProvider(AppSettingKeys.defaultNumEditMode)) ? DialogType.numEdit : DialogType.rangeEdit;
  }

  @override
  Stream<_Model> build(String machineUUID) async* {
    // logger.i('Rebuilding fansCardController for $machineUUID');

    // This might be WAY to fine grained. Riverpod will check based on the emitted value if the widget should rebuild.
    // This means that if the value is the same, the widget will not rebuild.
    // Otherwise Riverpod will check the same for us in the SelectAsync/SelectAs method. So we can directly get the RAW provider anyway!
    var printFan = ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.printFan));
    var fans = ref.watchAsSubject(printerProvider(machineUUID).selectAs(
        (data) => data.fans.values.where((element) => !element.name.startsWith('_')).toList(growable: false)));
    var klippyCanReceiveCommands =
        ref.watchAsSubject(klipperProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands));

    yield* Rx.combineLatest3(
      printFan,
      fans,
      klippyCanReceiveCommands,
      (a, b, c) => _Model(printFan: a, fans: b, klippyCanReceiveCommands: c),
    );
  }

  Future<void> onEditPartFan() async {
    if (!state.hasValue) return;
    var fan = state.requireValue.printFan;
    if (fan == null) return;

    var resp = await _dialogService.show(DialogRequest(
      type: _dialogMode,
      title: tr('dialogs.fan_speed.title', args: [tr('pages.dashboard.control.fan_card.part_fan')]),
      cancelBtn: tr('general.cancel'),
      confirmBtn: tr('general.confirm'),
      data: NumberEditDialogArguments(
        current: fan.speed * 100.round(),
        min: 0,
        max: 100,
      ),
    ));

    if (resp != null && resp.confirmed && resp.data != null) {
      num v = resp.data;
      _printerService.partCoolingFan(v.toDouble() / 100);
    }
  }

  Future<void> onEditGenericFan(GenericFan fan) async {
    if (!state.hasValue) return;

    var resp = await _dialogService.show(DialogRequest(
      type: _dialogMode,
      title: tr('dialogs.fan_speed.title', args: [beautifyName(fan.name)]),
      cancelBtn: tr('general.cancel'),
      confirmBtn: tr('general.confirm'),
      data: NumberEditDialogArguments(
        current: fan.speed * 100.round(),
        min: 0,
        max: 100,
      ),
    ));

    if (resp != null && resp.confirmed && resp.data != null) {
      num v = resp.data;
      _printerService.genericFanFan(fan.name, v.toDouble() / 100);
    }
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required PrintFan? printFan,
    required List<NamedFan> fans,
  }) = __Model;

  bool get hasPrintFan => printFan != null;
}
