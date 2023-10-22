/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flip_card/flip_card_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'heaters_sensor_card.dart';
import 'temperature_preset_card.dart';

class TemperatureSensorPresetCard extends HookConsumerWidget {
  const TemperatureSensorPresetCard({
    Key? key,
    required this.machineUUID,
  }) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var flipController = useRef(FlipCardController());

    return FlipCard(
      controller: flipController.value,
      flipOnTouch: false,
      direction: FlipDirection.VERTICAL,
      // back: const Text('front'),
      front: HeaterSensorCard(
          machineUUID: machineUUID,
          trailing: TextButton(
            onPressed: flipController.value.toggleCard,
            child: const Text('pages.dashboard.general.temp_card.presets_btn').tr(),
          )),
      back: TemperaturePresetCard(
        machineUUID: machineUUID,
        trailing: TextButton(
          onPressed: flipController.value.toggleCard,
          child: const Text('pages.dashboard.general.temp_card.sensors').tr(),
        ),
        onPresetApplied: flipController.value.toggleCard,
      ),
    );
  }
}

class HeaterSensorPresetCardTitle extends ConsumerWidget {
  const HeaterSensorPresetCardTitle({
    super.key,
    required this.machineUUID,
    required this.title,
    this.trailing,
  });

  final String machineUUID;
  final Widget title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isHeating = ref
            .watch(printerProvider(machineUUID).selectAs((data) =>
                (data.extruders.firstWhereOrNull((element) => element.target > 0)?.target ??
                    data.heaterBed?.target ??
                    0) >
                0))
            .valueOrNull ==
        true;

    return ListTile(
      leading: Icon(
        FlutterIcons.fire_alt_faw5s,
        color: isHeating ? Colors.deepOrange : null,
      ),
      title: title,
      trailing: trailing,
    );
  }
}

class HeaterSensorPresetCardLoading extends StatelessWidget {
  const HeaterSensorPresetCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Shimmer.fromColors(
          baseColor: Colors.grey,
          highlightColor: themeData.colorScheme.background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CardTitleSkeleton.trailingText(
                leading: const Icon(
                  FlutterIcons.fire_alt_faw5s,
                  color: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                  var height = constraints.maxWidth * 0.35;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(child: _tile(height)),
                          Flexible(child: _tile(height)),
                        ],
                      ),
                      Container(
                        width: 30,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  );
                }),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(double height) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
        ),
        width: double.infinity,
        height: height,
      ),
    );
  }
}
