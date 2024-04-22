/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../routing/app_router.dart';
import '../../../components/webcam/webcam.dart';

part 'webcam_card.freezed.dart';
part 'webcam_card.g.dart';

class WebcamCard extends HookConsumerWidget {
  const WebcamCard({super.key, required this.machineUUID});

  final String machineUUID;

  CompositeKey get _hadWebcamKey => CompositeKey.keyWithString(UiKeys.hadWebcam, machineUUID);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_webcamCardControllerProvider(machineUUID).notifier);
    var hadWebcam = ref.read(boolSettingProvider(_hadWebcamKey));

    // Only show card if there is a webcam
    var model = ref.watch(_webcamCardControllerProvider(machineUUID).selectAs((data) => data.allCams.isNotEmpty));

    Widget widget = switch (model) {
      // We have a value and the model (allCams != empty) is true
      AsyncValue(hasValue: true, value: true) => Card(
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
        ),
      // The model returned an error
      AsyncError(:final error) => _Card(
          key: const Key('wcE'),
          machineUUID: machineUUID,
          child: Center(
            child: Column(
              key: UniqueKey(),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline),
                const SizedBox(height: 30),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.onRetry,
                  icon: const Icon(
                    Icons.restart_alt_outlined,
                  ),
                  label: const Text('general.retry').tr(),
                ),
              ],
            ),
          ),
        ),
      // The model is loading for the first time and we previously had a webcam -> show loading
      AsyncLoading() when hadWebcam => const _WebcamCardLoading(key: Key('wcL')),
      // Default do not show anything. E.g. if we never had a webcam or we have a model with empty webcam
      _ => const SizedBox.shrink(key: Key('wcN')),
    };

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      // reverseDuration: Duration(seconds: 3),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      // duration: kThemeAnimationDuration,
      transitionBuilder: (child, anim) => SizeAndFadeTransition(
        sizeAndFadeFactor: anim,
        sizeAxisAlignment: -1,
        child: child,
      ),
      // transitionBuilder: (child, anim) => SizeAndFadeTransition(sizeAndFadeFactor: anim, child: child),
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

class _Card extends StatelessWidget {
  const _Card({super.key, required this.machineUUID, required this.child});

  final String machineUUID;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CardTitle(machineUUID: machineUUID),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: child,
          ),
        ],
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
    var model = ref.watch(_webcamCardControllerProvider(machineUUID)).valueOrNull;

    if (model == null || model.allCams.length <= 1) {
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
  CompositeKey get _hadWebcamKey => CompositeKey.keyWithString(UiKeys.hadWebcam, machineUUID);

  SettingService get _settingService => ref.read(settingServiceProvider);

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.webcamIndex, machineUUID);

  bool? _wroteValue;

  @override
  Future<_Model> build(String machineUUID) async {
    ref.keepAliveFor();

    logger.i('Rebuilding WebcamCardController for $machineUUID');

    var machine = await ref.watch(machineProvider(machineUUID).future);

    var allWebcams = await ref.watch(allWebcamInfosProvider(machineUUID).future);

    var readInt = _settingService.readInt(_settingsKey, 0);
    var idx = (state.whenData((value) => value.selected).valueOrNull ?? readInt);

    if (allWebcams.isEmpty) {
      idx = 0;
    } else {
      idx = idx.clamp(0, allWebcams.length - 1);
    }

    if (_wroteValue != allWebcams.isNotEmpty) {
      _wroteValue = allWebcams.isNotEmpty;
      _settingService.writeBool(_hadWebcamKey, allWebcams.isNotEmpty);
    }
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

  void onRetry() {
    // this is just to make sure we recall the webcam API if that was the reason
    ref.invalidate(allWebcamInfosProvider(machineUUID));
    // ref.invalidateSelf();
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
