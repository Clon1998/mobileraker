/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/power/power_device.dart';
import 'package:common/data/enums/power_state_enum.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/power_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/horizontal_scroll_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

part 'power_api_card.freezed.dart';
part 'power_api_card.g.dart';

class PowerApiCard extends HookConsumerWidget {
  const PowerApiCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  static Widget loading() {
    return const _PowerApiCardLoading();
  }

  final String machineUUID;

  CompositeKey get _hadPowerApi => CompositeKey.keyWithString(UiKeys.hadPowerAPI, machineUUID);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    var hadPowerApi = ref.read(boolSettingProvider(_hadPowerApi));

    return AsyncGuard(
      animate: true,
      debugLabel: 'PowerApiCard-$machineUUID',
      toGuard: _powerApiCardControllerProvider(machineUUID).selectAs((data) => data.showCard),
      childOnLoading: hadPowerApi ? const _PowerApiCardLoading() : null,
      childOnError: (error, _) => _ProviderError(machineUUID: machineUUID, error: error),
      childOnData: Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(FlutterIcons.power_fea),
                title: const Text(
                  'pages.dashboard.control.power_card.title',
                ).tr(),
              ),
              Consumer(builder: (context, ref, child) {
                var model = ref.watch(_powerApiCardControllerProvider(machineUUID).selectRequireValue((data) => data));
                return AdaptiveHorizontalScroll(
                  pageStorageKey: 'powers$machineUUID',
                  children: [
                    for (var device in model.devices)
                      _PowerDeviceCard(machineUUID: machineUUID, powerDevice: device, isPrinting: model.isPrinting),
                  ],
                );
              })
            ],
          ),
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
      overrides: [
        _powerApiCardControllerProvider(_machineUUID).overrideWith(_PowerApiCardPreviewController.new),
      ],
      child: const PowerApiCard(machineUUID: _machineUUID),
    );
  }
}

class _PowerApiCardLoading extends StatelessWidget {
  const _PowerApiCardLoading({super.key});

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
              contentTextStyles: [
                themeData.textTheme.bodySmall,
                themeData.textTheme.headlineSmall,
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PowerDeviceCard extends ConsumerWidget {
  const _PowerDeviceCard({super.key, required this.machineUUID, required this.powerDevice, required this.isPrinting});

  final String machineUUID;
  final PowerDevice powerDevice;
  final bool isPrinting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_powerApiCardControllerProvider(machineUUID).notifier);

    return CardWithSwitch(
      value: powerDevice.status == PowerState.on,
      onChanged: (powerDevice.status == PowerState.error ||
              powerDevice.status == PowerState.unknown ||
              powerDevice.lockedWhilePrinting && isPrinting ||
              powerDevice.status == PowerState.init)
          ? null
          : (d) => controller.updateDeviceState(
                powerDevice,
                d ? PowerState.on : PowerState.off,
              ),
      builder: (context) {
        var themeData = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AutoSizeText(
              beautifyName(powerDevice.name),
              minFontSize: 8,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: themeData.textTheme.bodySmall,
            ),
            Text(
              powerDevice.status.name.capitalize,
              style: themeData.textTheme.headlineSmall,
            ),
          ],
        );
      },
    );
  }
}

class _ProviderError extends ConsumerWidget {
  const _ProviderError({super.key, required this.machineUUID, required this.error});

  final String machineUUID;
  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String message = error.toString();
    var e = error;
    if (e is MobilerakerException) {
      // title = e.message;
      if (e.parentException != null) {
        message = e.parentException.toString();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(FlutterIcons.power_fea),
              title: const Text('pages.dashboard.control.power_card.title').tr(),
            ),
            SimpleErrorWidget(
              title: const Text('pages.dashboard.control.power_card.provider_error_title').tr(),
              body: Text(message),
              action: TextButton.icon(
                onPressed: () {
                  logger.i('Invalidating power service for $machineUUID');
                  ref.invalidate(powerServiceProvider(machineUUID));
                },
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('general.retry').tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@riverpod
class _PowerApiCardController extends _$PowerApiCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  PowerService get _powerService => ref.read(powerServiceProvider(machineUUID));

  CompositeKey get _hadPowerApi => CompositeKey.keyWithString(UiKeys.hadPowerAPI, machineUUID);

  bool? _wroteValue;

  @override
  Future<_Model> build(String machineUUID) async {
    ref.keepAliveFor();

    logger.i('Rebuilding PowerApiCardController for $machineUUID');

    var hasPowerAPI = await ref.watch(klipperProvider(machineUUID).selectAsync((data) => data.hasPowerComponent));

    List<PowerDevice> devices = [];
    bool isPrinting = false;
    if (hasPowerAPI) {
      // We are using the sync version because we do not want to wait for the printer state -> Power Api Card should work even if printer/klipper is not connected
      isPrinting =
          ref.watch(printerProvider(machineUUID).select((d) => d.valueOrNull?.print.state == PrintState.printing));
      devices = await ref
          .watch(powerDevicesProvider(machineUUID).future)
          .then((value) => value.where((element) => !element.name.startsWith('_')).toList());
    }

    // await Future.delayed(const Duration(milliseconds: 2000));

    // Reduce the amount of writes to the setting service
    var tmp = hasPowerAPI && devices.isNotEmpty;
    if (_wroteValue != tmp) {
      _wroteValue = tmp;
      _settingService.writeBool(_hadPowerApi, tmp);
    }
    return _Model(devices: devices, isPrinting: isPrinting);
  }

  Future<PowerState> updateDeviceState(PowerDevice device, PowerState state) async {
    return _powerService.setDeviceStatus(device.name, state);
  }
}

class _PowerApiCardPreviewController extends _PowerApiCardController {
  @override
  Future<_Model> build(String machineUUID) {
    const model = _Model(
      devices: [
        PowerDevice(name: 'Preview Device', status: PowerState.on, type: PowerDeviceType.gpio),
        PowerDevice(name: 'Preview Pi', status: PowerState.off, type: PowerDeviceType.mqtt),
      ],
      isPrinting: false,
    );
    state = const AsyncValue.data(model);
    return Future.value(model);
  }

  @override
  Future<PowerState> updateDeviceState(PowerDevice device, PowerState state) async {
    // Some fake data processing
    await Future.delayed(const Duration(milliseconds: 100));
    final cModel = this.state.requireValue;

    final uModel = cModel.copyWith(
        devices: cModel.devices.map((d) => d.name == device.name ? d.copyWith(status: state) : d).toList());

    this.state = AsyncValue.data(uModel);

    return state;
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required List<PowerDevice> devices,
    required bool isPrinting,
  }) = __Model;

  bool get showCard => devices.isNotEmpty;
}
