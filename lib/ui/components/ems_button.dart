/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class EmergencyStopBtn extends ConsumerWidget {
  const EmergencyStopBtn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    KlipperState klippyState = ref.watch(klipperSelectedProvider.select((value) => value.valueOrNull?.klippyState ?? KlipperState.disconnected));

    return IconButton(
      color: Theme.of(context).extension<CustomColors>()?.danger ?? Colors.red,
      icon: const Icon(
        FlutterIcons.skull_outline_mco,
        size: 26,
      ),
      tooltip: tr('pages.dashboard.ems_btn'),
      onPressed: klippyState == KlipperState.ready
          ? () async {
              if (ref
                  .read(settingServiceProvider)
                  .readBool(AppSettingKeys.confirmEmergencyStop, true)) {
                var result = await ref.read(dialogServiceProvider).showConfirm(
                      title: "Emergency Stop - Confirmation",
                      body: "Are you sure?",
                      confirmBtn: "STOP!",
                      confirmBtnColor:
                          Theme.of(context).extension<CustomColors>()?.danger ?? Colors.red,
                    );
                if (!(result?.confirmed ?? false)) return;
              }

              ref.read(klipperServiceSelectedProvider).emergencyStop();
      }
          : null,
    );
  }
}
