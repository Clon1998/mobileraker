/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
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
import 'package:mobileraker/ui/animation/SizeAndFadeTransition.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../routing/app_router.dart';
import '../../../components/webcam/webcam.dart';

part 'webcam_card.freezed.dart';
part 'webcam_card.g.dart';

class WebcamCard extends HookConsumerWidget {
  WebcamCard({super.key, required this.machineUUID});

  final String machineUUID;

  late final CompositeKey _hadWebcamKey = CompositeKey.keyWithString(UiKeys.hadWebcam, machineUUID);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settingService = ref.watch(settingServiceProvider);
    var hadWebcam = settingService.readBool(_hadWebcamKey);

    logger.i('Rebuilding WebcamCard for $machineUUID');
    // Only show card if there is a webcam
    var model = ref.watch(_webcamCardControllerProvider(machineUUID).selectAs((data) => data.allCams.isNotEmpty));
    var showCard = model.valueOrNull;
    var showLoading = model.isLoading && !model.isReloading;
//TODO: We need to properly handle all states! The controller might still throw an error, as the all webcams is its own provider. It is not guaranteed that it is already loaded and that it is valid!!!

    useEffect(() {
      if (showCard == null) return;
      settingService.writeBool(_hadWebcamKey, showCard);
    }, [showCard]);

    logger.w('showCard: $showCard, hadWebcam: $hadWebcam');

    final Widget widget;

    if (!hadWebcam && showCard != true || showCard == false) {
      return const SizedBox.shrink(key: Key('wcN'));
    } else if (showLoading) {
      widget = const _WebcamCardLoading(key: Key('wcL'));
    } else {
      widget = Card(
        key: const Key('wcD'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CardTitle(machineUUID: machineUUID),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: _CardBody(machineUUID: machineUUID),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      transitionBuilder: (child, anim) => SizeAndFadeTransition(sizeAndFadeFactor: anim, child: child),
      child: widget,
    );
  }
}

class _WebcamCardLoading extends StatelessWidget {
  const _WebcamCardLoading({super.key});

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
            CardTitleSkeleton.trailingText(),
            const Flexible(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
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
    return ListTile(
      leading: const Icon(FlutterIcons.webcam_mco),
      title: const Text('pages.dashboard.general.cam_card.webcam').tr(),
      trailing: _Trailing(machineUUID: machineUUID),
    );
  }
}

class _Trailing extends ConsumerWidget {
  const _Trailing({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_webcamCardControllerProvider(machineUUID).notifier);
    var model = ref.watch(_webcamCardControllerProvider(machineUUID).requireValue());

    if (model.allCams.length <= 1) {
      return const SizedBox.shrink();
    }

    return DropdownButton(
      value: model.selected,
      onChanged: controller.onSelectedChange,
      items: [
        for (var i = 0; i < model.allCams.length; i++)
          DropdownMenuItem(value: i, child: Text(beautifyName(model.allCams[i].name))),
      ],
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_webcamCardControllerProvider(machineUUID).notifier);
    var model = ref.watch(_webcamCardControllerProvider(machineUUID).requireValue());

    return Center(
      child: Webcam(
        machine: model.machine,
        webcamInfo: model.activeCam,
        stackContent: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                color: Colors.white,
                icon: const Icon(Icons.aspect_ratio),
                tooltip: 'pages.dashboard.general.cam_card.fullscreen'.tr(),
                onPressed: controller.onFullScreenTap,
              ),
            ),
          ),
        ],
        imageBuilder: _imageBuilder,
        showFpsIfAvailable: true,
      ),
    );
  }

  Widget _imageBuilder(BuildContext context, Widget imageTransformed) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      child: imageTransformed,
    );
  }
}

@riverpod
class _WebcamCardController extends _$WebcamCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.webcamIndex, machineUUID);

  @override
  Future<_Model> build(String machineUUID) async {
    ref.keepAliveFor();

    logger.i('Rebuilding WebcamCardController for $machineUUID');
    var machine = await ref.watch(machineProvider(machineUUID).future);

    var allWebcams = await ref.watch(allWebcamInfosProvider(machineUUID).future);

    var readInt = _settingService.readInt(_settingsKey, 0);
    logger.i('Read webcam index: ${readInt}');
    var idx = (state.whenData((value) => value.selected).valueOrNull ?? readInt).clamp(0, allWebcams.length - 1);

    // await Future.delayed(const Duration(seconds: 5));
    // throw Exception('Test Error');

    return _Model(machine: machine!, selected: idx, allCams: allWebcams);
  }

  void onSelectedChange(int? index) {
    if (index == null) return;
    state = state.whenData((value) => value.copyWith(selected: index));
    _settingService.writeInt(_settingsKey, index);
  }

  void onFullScreenTap() {
    if (!state.hasValue) return;
    var value = state.requireValue;
    ref.read(goRouterProvider).pushNamed(
      AppRoute.fullCam.name,
      extra: {'machine': value.machine, 'selectedCam': value.activeCam},
    );
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required List<WebcamInfo> allCams,
    required int? selected,
    required Machine machine,
  }) = __Model;

  bool get camSelected => allCams.isNotEmpty && selected != null;

  WebcamInfo get activeCam => allCams[selected!];
}
