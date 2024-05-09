/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomedAxisChip extends ConsumerWidget {
  const HomedAxisChip({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = printerProvider(machineUUID);
    int homedAxisCnt = ref.watch(provider.selectAs((value) => value.toolhead.homedAxes.length)).valueOrNull ?? 0;

    return Tooltip(
      message: 'pages.dashboard.general.move_card.homed'.tr(),
      child: Chip(
        avatar: const Icon(
          FlutterIcons.shield_home_mco,
          // color: Colors.white,
          size: 20,
        ),
        // shape: StadiumBorder(side: BorderSide(color: Colors.limeAccent)),
        side: BorderSide(
          color: (homedAxisCnt > 0) ? Colors.lightGreen : Colors.orangeAccent,
          width: 3,
        ),
        // shape: ContinuousRectangleBorder(side: BorderSide(width: 1),),
        label: Text(_homedChipTitle(ref.read(provider).valueOrNull?.toolhead.homedAxes ?? {})),
        // backgroundColor:
        //     (homedAxisCnt > 0) ? Colors.lightGreen : Colors.orangeAccent,
      ),
    );
  }

  String _homedChipTitle(Set<PrinterAxis> homedAxes) {
    if (homedAxes.isEmpty) {
      return 'general.none'.tr().toUpperCase();
    }
    List<PrinterAxis> l = homedAxes.toList();
    l.sort((a, b) => a.index.compareTo(b.index));
    return l.map((e) => EnumToString.convertToString(e)).join();
  }
}
