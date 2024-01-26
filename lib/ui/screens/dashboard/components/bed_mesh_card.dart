/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bed_mesh/bed_mesh_legend.dart';
import 'package:mobileraker/ui/components/bed_mesh/bed_mesh_plot.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'bed_mesh_card.freezed.dart';
part 'bed_mesh_card.g.dart';

class BedMeshCard extends HookConsumerWidget {
  const BedMeshCard({Key? key, required this.machineUUID}) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading =
        ref.watch(_controllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));

    if (showLoading) return const _ControlExtruderLoading();

    var showCard = ref.watch(_controllerProvider(machineUUID).selectAs((value) => value.hasMeshComponent)).requireValue;
    // If the printer has no bed mesh component, we don't show the card
    if (!showCard) return const SizedBox.shrink();

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CardTitle(machineUUID: machineUUID),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: _CardBody(machineUUID: machineUUID),
          ),
        ],
      ),
    );
  }
}

class _ControlExtruderLoading extends StatelessWidget {
  const _ControlExtruderLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Placeholder();
  }
}

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);

    return const ListTile(
      leading: Icon(FlutterIcons.grid_mco),
      title: Row(children: [
        Text('Bed Mesh'),
      ]),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // return Placeholder();
    var model = ref.watch(_controllerProvider(machineUUID)).requireValue;

    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.bedMesh?.profileName?.isNotEmpty == true) ...[
            BedMeshLegend(valueRange: model.bedMesh!.zValueRangeProbed),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: BedMeshPlot(bedMesh: model.bedMesh, bedMin: model.bedMin, bedMax: model.bedMax),
          ),
          // _GradientLegend(machineUUID: machineUUID),
          // _ScaleIndicator(gradient: invertedGradient, min: zMin, max: zMax),
        ],
      ),
    );
  }
}

@riverpod
class _Controller extends _$Controller {
  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();

    var printerProviderr = printerProvider(machineUUID);
    var klipperProviderr = klipperProvider(machineUUID);

    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProviderr.selectAs((value) => value.klippyCanReceiveCommands),
    );
    var bedMesh = ref.watchAsSubject(
      printerProviderr.selectAs((value) => value.bedMesh),
    );
    var configFile = ref.watchAsSubject(
      printerProviderr.selectAs((value) => value.configFile),
    );

    yield* Rx.combineLatest3(
      klippyCanReceiveCommands,
      bedMesh,
      configFile,
      (a, b, c) => _Model(
        klippyCanReceiveCommands: a,
        bedMesh: b,
        bedMin: (c.minX, c.minY),
        bedMax: (c.maxX, c.maxY),
        bedXAxisSize: c.sizeX,
        bedYAxisSize: c.sizeY,
        hasMeshComponent: c.hasBedMesh && b != null,
      ),
    );
  }

  PrinterService get _printerService => ref.read(printerServiceSelectedProvider);
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required BedMesh? bedMesh,
    required (double, double) bedMin, //x, y
    required (double, double) bedMax, //x,y
    required double bedXAxisSize,
    required double bedYAxisSize,
    required bool hasMeshComponent,
  }) = __Model;

  bool get hasBedMesh => bedMesh != null;
}
