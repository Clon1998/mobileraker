import 'package:easy_localization/easy_localization.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab_viewmodel.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';

class HomedAxisChip extends ConsumerWidget {
  const HomedAxisChip({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int homedAxisCnt = ref.watch(machinePrinterKlippySettingsProvider.select(
        (value) =>
            value.valueOrFullNull!.printerData.toolhead.homedAxes.length));

    return Chip(
      avatar: Icon(
        FlutterIcons.shield_home_mco,
        color: Theme.of(context).chipTheme.deleteIconColor,
        size: 20,
      ),
      label: Text(_homedChipTitle(ref.read(machinePrinterKlippySettingsProvider).valueOrFullNull!.printerData.toolhead.homedAxes)),
      backgroundColor:
          (homedAxisCnt > 0) ? Colors.lightGreen : Colors.orangeAccent,
    );
  }

  String _homedChipTitle(Set<PrinterAxis> homedAxes) {
    if (homedAxes.isEmpty) {
      return 'general.none'.tr().toUpperCase();
    } else {
      List<PrinterAxis> l = homedAxes.toList();
      l.sort((a, b) => a.index.compareTo(b.index));
      return l.map((e) => EnumToString.convertToString(e)).join();
    }
  }
}
