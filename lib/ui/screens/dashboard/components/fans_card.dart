/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
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
import 'package:common/util/extensions/ref_extension.dart';
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
import 'package:rxdart/rxdart.dart';
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
    logger.i('Rebuilding fans card for $machineUUID');

    return AsyncGuard(
      animate: true,
      debugLabel: 'FansCard-$machineUUID',
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
      overrides: [
        _fansCardControllerProvider(_machineUUID).overrideWith(_FansCardPreviewController.new),
      ],
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

    return AdaptiveHorizontalScroll(
      pageStorageKey: 'fans$machineUUID',
      children: [
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
      _ => 'Fan',
    };

    VoidCallback? onTap = switch (fan) {
      GenericFan() when klippyCanReceiveCommands => () => controller.onEditGenericFan(fan),
      PrintFan() when klippyCanReceiveCommands => () => controller.onEditPartFan(fan),
      _ => null,
    };

    VoidCallback? onLongTap = switch (fan) {
      GenericFan() when klippyCanReceiveCommands => () => controller.onToggleFan(fan),
      PrintFan() when klippyCanReceiveCommands => () => controller.onPrintFan(fan),
      _ => null,
    };

    return _FanCard(name: name, speed: fan.speed, rpm: fan.rpm, onTap: onTap, onLongTap: onLongTap);
  }
}

class _FanCard extends StatelessWidget {
  static const double icoSize = 30;

  final String name;
  final double speed;
  final double? rpm;
  final VoidCallback? onTap;
  final VoidCallback? onLongTap;

  const _FanCard({
    super.key,
    required this.name,
    required this.speed,
    this.rpm,
    this.onTap,
    this.onLongTap,
  });

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
                      Text(
                        '${tachFormat.format(rpm)} rpm',
                        maxLines: 1,
                        style: themeData.textTheme.bodySmall,
                      ),
                  ],
                ),
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
    logger.i('Rebuilding fansCardController for $machineUUID');

    // This might be WAY to fine grained. Riverpod will check based on the emitted value if the widget should rebuild.
    // This means that if the value is the same, the widget will not rebuild.
    // Otherwise Riverpod will check the same for us in the SelectAsync/SelectAs method. So we can directly get the RAW provider anyway!
    var ordering = await ref.watch(machineSettingsProvider(machineUUID).selectAsync((value) => value.fanOrdering));

    int getOrderingIndex(Fan fan) {
      return ordering.indexWhere((element) {
        return switch (fan) {
          NamedFan() => element.name == fan.name,
          PrintFan() => element.kind == ConfigFileObjectIdentifiers.fan,
          _ => false
        };
      });
    }

    var klippyCanReceiveCommands =
        ref.watchAsSubject(klipperProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands));

    var fans = ref
        .watchAsSubject(printerProvider(machineUUID).selectAs((value) {
      var printFan = value.printFan;
      var fans = value.fans;

      return [
        if (printFan != null) printFan,
        ...fans.values,
      ];
    }))
        // Use map here since this prevents to many operations if the original list not changes!
        .map((fans) {
      var output = <Fan>[];

      for (var fan in fans) {
        if (fan case NamedFan(name: var name) when name.startsWith('_')) continue;
        output.add(fan);
      }

      // Sort output by ordering, if ordering is not found it will be placed at the end
      output.sort((a, b) {
        var aIndex = getOrderingIndex(a);
        var bIndex = getOrderingIndex(b);

        if (aIndex == -1) aIndex = output.length;
        if (bIndex == -1) bIndex = output.length;

        return aIndex.compareTo(bIndex);
      });
      return output;
    });

    yield* Rx.combineLatest2(
      klippyCanReceiveCommands,
      fans,
      (a, b) => _Model(
        klippyCanReceiveCommands: a,
        fans: b,
      ),
    );
  }

  Future<void> onEditPartFan(PrintFan fan) async {
    if (!state.hasValue) return;

    var resp = await _dialogService.show(DialogRequest(
      type: _dialogMode,
      title: tr('dialogs.fan_speed.title', args: [tr('pages.dashboard.control.fan_card.part_fan')]),
      dismissLabel: tr('general.cancel'),
      actionLabel: tr('general.confirm'),
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
      dismissLabel: tr('general.cancel'),
      actionLabel: tr('general.confirm'),
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

  void onToggleFan(GenericFan fan) {
    if (!state.hasValue) return;

    if (fan.speed > 0) {
      _printerService.genericFanFan(fan.name, 0);
    } else {
      _printerService.genericFanFan(fan.name, 1);
    }
  }

  void onPrintFan(PrintFan fan) {
    if (!state.hasValue) return;

    if (fan.speed > 0) {
      _printerService.partCoolingFan(0);
    } else {
      _printerService.partCoolingFan(1);
    }
  }
}

class _FansCardPreviewController extends _FansCardController {
  @override
  Stream<_Model> build(String machineUUID) {
    logger.i('Rebuilding fansCardController for $machineUUID');

    state = const AsyncValue.data(_Model(
      klippyCanReceiveCommands: true,
      fans: [
        PrintFan(speed: 0),
        ControllerFan(name: 'Preview Fan', speed: 0),
      ],
    ));

    return const Stream.empty();
  }

  @override
  Future<void> onEditPartFan(PrintFan fan) async {
    // Do nothing preview
  }

  @override
  Future<void> onEditGenericFan(GenericFan fan) async {
    // Do nothing preview
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<Fan> fans,
  }) = __Model;
}
