/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../service/ui/dialog_service_impl.dart';

class SnapshotWebcamSetting extends ConsumerWidget {
  const SnapshotWebcamSetting({
    super.key,
    required this.availableWebcams,
    this.selectedWebcam,
    this.onChanged,
  });

  final List<WebcamInfo> availableWebcams;
  final WebcamInfo? selectedWebcam;
  final ValueChanged<WebcamInfo?>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSupporter = ref.watch(isSupporterProvider);
    final dialogService = ref.watch(dialogServiceProvider);
    final themeData = Theme.of(context);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'pages.setting.notification.snapshot_webcam_label'.tr(),
        labelStyle: themeData.textTheme.labelLarge,
        helperText: 'pages.setting.notification.snapshot_webcam_helper'.tr(),
        helperMaxLines: 99,
        suffix: IconButton(
          constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
          icon: const Icon(FlutterIcons.hand_holding_heart_faw5s),
          onPressed: () {
            dialogService.show(DialogRequest(
              type: DialogType.supporterOnlyFeature,
              body: tr('components.supporter_only_feature.snapshot_webcam'),
            ));
          },
        ).unless(isSupporter),
      ),
      child: DropdownButton<WebcamInfo?>(
        value: selectedWebcam.only(isSupporter),
        underline: SizedBox.shrink(),
        isExpanded: true,
        isDense: true,
        selectedItemBuilder: (context) => [
          Text('general.disabled').tr(),
          for (var webcam in availableWebcams) Text(webcam.name),
        ],
        items: [
          DropdownMenuItem<WebcamInfo?>(
            value: null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('general.disabled').tr(),
                Text('pages.setting.notification.snapshot_webcam_disabled', style: themeData.textTheme.bodySmall).tr(),
              ],
            ),
          ),
          for (var webcam in availableWebcams)
            DropdownMenuItem<WebcamInfo>(
              value: webcam,
              enabled: webcam.service.companionSupported,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(webcam.name),
                  Text(
                      webcam.service.companionSupported
                          ? webcam.streamUrl.toString()
                          : tr('pages.setting.notification.snapshot_webcam_type_unsupported'),
                      style: themeData.textTheme.bodySmall),
                ],
              ),
            ),
        ],
        onChanged: onChanged.only(isSupporter),
      ),
    );
  }
}
