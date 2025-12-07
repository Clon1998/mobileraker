/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/config/fan/config_fan.dart';
import 'package:common/data/dto/config/fan/config_print_cooling_fan.dart';
import 'package:common/data/dto/machine/fans/controller_fan.dart';
import 'package:common/data/dto/machine/fans/fan.dart';
import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:common/data/dto/machine/fans/named_fan.dart';
import 'package:common/data/dto/machine/fans/print_fan.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/horizontal_scroll_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../components/adaptive_horizontal_scroll.dart';
import '../../../components/card_with_button.dart';
import '../../../components/dialog/edit_form/num_edit_form_dialog.dart';
import '../../../components/spinning_fan.dart';

part 'fans_card.freezed.dart';
part 'fans_card.g.dart';

class FansCard extends HookConsumerWidget {
  const FansCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  static Widget loading() {
    return const _FansCardLoading();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    talker.info('Rebuilding fans card for $machineUUID');

    return AsyncGuard(
      animate: true,
      // debugLabel: 'FansCard-$machineUUID',
      toGuard: _fansCardControllerProvider(machineUUID).selectAs((data) => data.fans.isNotEmpty),
      childOnLoading: const _FansCardLoading(),
      childOnData: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardTitle(machineUUID: machineUUID),
            _CardBody(machineUUID: machineUUID),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Preview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _Preview({super.key});

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [_fansCardControllerProvider(_machineUUID).overrideWith(_FansCardPreviewController.new)],
      child: const FansCard(machineUUID: _machineUUID),
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
            HorizontalScrollSkeleton(
              contentTextStyles: [themeData.textTheme.bodySmall, themeData.textTheme.headlineSmall],
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

    // talker.info('Rebuilding fans card title');

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
    // talker.info('Rebuilding fans card body');

    var fansCount = ref.watch(_fansCardControllerProvider(machineUUID).selectRequireValue((data) => data.fans.length));

    return AdaptiveHorizontalScroll(
      pageStorageKey: 'fans$machineUUID',
      children: [
        for (var i = 0; i < fansCount; i++)
          _Fan(
            fanProvider: _fansCardControllerProvider(machineUUID).selectRequireValue((value) {
              // ignore: avoid-unsafe-collection-methods
              final fan = value.fans[i];
              final key = switch (fan) {
                NamedFan(name: final n) => (fan.kind, n.toLowerCase()),
                PrintFan() => (ConfigFileObjectIdentifiers.fan, 'print_fan'),
                _ => (fan.kind, ''),
              };

              final fanConf = value.fanConfigs[key];

              return (fan, fanConf);
            }),
            machineUUID: machineUUID,
          ),
      ],
    );
  }
}

class _Fan extends ConsumerWidget {
  const _Fan({super.key, required this.fanProvider, required this.machineUUID});

  final ProviderListenable<(Fan, ConfigFan?)?> fanProvider;
  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(fanProvider);

    if (data == null) {
      return const SizedBox.shrink();
    }
    talker.info('Rebuilding fan card for $data');

    final (fan, fanConfig) = data;

    var klippyCanReceiveCommands = ref.watch(
      _fansCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands),
    );
    var controller = ref.watch(_fansCardControllerProvider(machineUUID).notifier);

    String name = switch (fan) {
      NamedFan(name: final n) => beautifyName(n),
      PrintFan() => 'pages.dashboard.control.fan_card.part_fan'.tr(),
      // This should never happen since either its a PrintFan or a NamedFan
      _ => 'Fan',
    };

    VoidCallback? onTap = switch (fan) {
      GenericFan() || PrintFan() when klippyCanReceiveCommands => () => controller.onEditFan(fan, fanConfig),
      _ => null,
    };

    VoidCallback? onLongTap = switch (fan) {
      GenericFan() || PrintFan() when klippyCanReceiveCommands => () => controller.onToggleFan(fan),
      _ => null,
    };

    // The normalized fan value between 0 and 1
    final normalizedSpeed = fan.speed / (fanConfig?.maxPower ?? 1);

    return _FanCard(name: name, speed: normalizedSpeed, rpm: fan.rpm, onTap: onTap, onLongTap: onLongTap);
  }
}

class _FanCard extends StatelessWidget {
  static const double icoSize = 30;

  final String name;
  final double speed;
  final double? rpm;
  final VoidCallback? onTap;
  final VoidCallback? onLongTap;

  const _FanCard({super.key, required this.name, required this.speed, this.rpm, this.onTap, this.onLongTap});

  @override
  Widget build(_) {
    return CardWithButton(
      buttonChild: onTap == null
          ? const Text('pages.dashboard.control.fan_card.static_fan_btn').tr()
          : const Text('general.set').tr(),
      onTap: onTap,
      onLongTap: onLongTap,
      builder: (context) {
        var themeData = Theme.of(context);

        var numberFormat = NumberFormat.percentPattern(context.locale.toStringWithSeparator());

        final tachFormat = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());

        return Tooltip(
          message: name,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      name,
                      minFontSize: 8,
                      style: themeData.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      speed > 0 ? numberFormat.format(speed) : 'general.off'.tr(),
                      style: themeData.textTheme.headlineSmall,
                    ),
                    if (rpm != null)
                      Text('${tachFormat.format(rpm)} rpm', maxLines: 1, style: themeData.textTheme.bodySmall),
                  ],
                ),
              ),
              speed > 0 ? SpinningFan(size: icoSize, speed: speed) : const Icon(FlutterIcons.fan_off_mco, size: icoSize),
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
  Future<_Model> build(String machineUUID) async {
    final orderingFuture = ref.watch(machineSettingsProvider(machineUUID).selectAsync((value) => value.fanOrdering));
    final klippyFuture = ref.watch(klipperProvider(machineUUID).selectAsync((data) => data.klippyCanReceiveCommands));
    final printerFuture = ref.watch(
      printerProvider(machineUUID).selectAsync((data) {
        final hasPrintFan = data.printFan != null;
        final hasPrintFanConfig = data.configFile.configPrintCoolingFan != null;

        return (
          <Fan>[if (hasPrintFan) data.printFan!, ...data.fans.values],
          {
            if (hasPrintFanConfig)
              (ConfigFileObjectIdentifiers.fan, 'print_fan'): data.configFile.configPrintCoolingFan!,
            ...data.configFile.fans,
          },
        );
      }),
    );

    final (ordering, klippyCanReceive, (fans, fanConfigs)) = await (orderingFuture, klippyFuture, printerFuture).wait;

    int getOrderingIndex(Fan fan) {
      return ordering.indexWhere((element) {
        return switch (fan) {
          NamedFan() => element.name == fan.name && element.kind == fan.kind,
          PrintFan() => element.kind == ConfigFileObjectIdentifiers.fan,
          _ => false,
        };
      });
    }

    fans.sort((a, b) => getOrderingIndex(a).compareTo(getOrderingIndex(b)));

    return _Model(klippyCanReceiveCommands: klippyCanReceive, fans: fans, fanConfigs: fanConfigs);
  }

  Future<void> onEditFan(Fan fan, ConfigFan? fanConfig) async {
    if (!state.hasValue) return;
    final normalizedSpeed = fan.speed / (fanConfig?.maxPower ?? 1) * 100;

    var resp = await _dialogService.show(
      DialogRequest(
        type: _dialogMode,
        title: tr('dialogs.fan_speed.title', args: [tr('pages.dashboard.control.fan_card.part_fan')]),
        dismissLabel: tr('general.cancel'),
        actionLabel: tr('general.confirm'),
        data: NumberEditDialogArguments(current: normalizedSpeed.round(), min: 0, max: 100),
      ),
    );

    if (resp != null && resp.confirmed && resp.data != null) {
      num v = resp.data;

      switch (fan) {
        case GenericFan():
          _printerService.genericFanFan(fan.name, v.toDouble() / 100);
          break;
        case PrintFan():
          _printerService.partCoolingFan(v.toDouble() / 100);
          break;
        default:
          talker.warning('Unknown fan type: $fan');
      }
      ;
    }
  }

  void onToggleFan(Fan fan) {
    if (!state.hasValue) return;

    final value = (fan.speed > 0) ? 0.0 : 1.0;

    switch (fan) {
      case GenericFan():
        _printerService.genericFanFan(fan.name, value);
        break;
      case PrintFan():
        _printerService.partCoolingFan(value);
        break;
      default:
        talker.warning('Unknown fan type: $fan');
    }
  }
}

class _FansCardPreviewController extends _FansCardController {
  @override
  Future<_Model> build(String machineUUID) {
    final model = _Model(
      klippyCanReceiveCommands: true,
      fans: [
        PrintFan(speed: 0),
        ControllerFan(name: 'Preview Fan', speed: 0),
      ],
      fanConfigs: {
        (ConfigFileObjectIdentifiers.fan, 'print_fan'): ConfigPrintCoolingFan(pin: 'PA1'),
        (ConfigFileObjectIdentifiers.controller_fan, 'preview fan'): ConfigPrintCoolingFan(pin: 'PA2'),
      },
    );

    state = AsyncValue.data(model);
    return Future.value(model);
  }

  @override
  Future<void> onEditFan(Fan fan, ConfigFan? fanConfig) async {
    // Do nothing preview
  }

  void onToggleFan(Fan fan) {
    // Do nothing preview
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<Fan> fans,
    required Map<(ConfigFileObjectIdentifiers, String), ConfigFan> fanConfigs,
  }) = __Model;
}
