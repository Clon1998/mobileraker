/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/timelapse_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/webcam_status_view.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

import '../../../../routing/app_router.dart';
import '../../../components/timelapse_frame_image.dart';
import '../../../components/webcam/webcam.dart';

part 'webcam_card.freezed.dart';
part 'webcam_card.g.dart';

/// Dropdown value used for the latest timelapse frame, as it is not part of the cam list
const int timelapseFrameIndex = -1;

class WebcamCard extends HookConsumerWidget {
  const WebcamCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  CompositeKey get _hadWebcamKey => CompositeKey.keyWithString(UiKeys.hadWebcam, machineUUID);

  CompositeKey get _hideWebcamKey => CompositeKey.keyWithString(UiKeys.hideWebcam, machineUUID);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    var controller = ref.watch(_webcamCardControllerProvider(machineUUID).notifier);
    var hadWebcam = ref.read(boolSettingProvider(_hadWebcamKey));
    var hidden = ref.read(boolSettingProvider(_hideWebcamKey));

    return AsyncGuard(
      debugLabel: 'WebcamCard-$machineUUID',
      animate: true,
      toGuard: _webcamCardControllerProvider(machineUUID).selectAs((data) => data.allCams.isNotEmpty),
      childOnLoading: switch ((hadWebcam, hidden)) {
        (true, false) => const _WebcamCardLoading(key: Key('wcL')),
        // Hidden cards only show their header, so there is no need for the large skeleton
        (true, true) => _Card(key: const Key('wcL'), machineUUID: machineUUID, child: const SizedBox.shrink()),
        _ => const SizedBox.shrink(key: Key('wcL')),
      },
      childOnError: (error, _) => _Card(
        key: const Key('wcE'),
        machineUUID: machineUUID,
        child: WebcamErrorView(error: error, onRetry: controller.onRetry),
      ),
      childOnData: _Card(
        key: const Key('wcD'),
        machineUUID: machineUUID,
        child: _CardBody(machineUUID: machineUUID),
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
      overrides: [_webcamCardControllerProvider(_machineUUID).overrideWith(_WebcamCardPreviewController.new)],
      child: const WebcamCard(machineUUID: _machineUUID),
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
                  child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({super.key, required this.machineUUID, required this.child});

  final String machineUUID;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If hidden, the child (and therefore the webcam stream) is not built at all.
    final hidden = ref.watch(boolSettingProvider(CompositeKey.keyWithString(UiKeys.hideWebcam, machineUUID)));

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CardTitle(machineUUID: machineUUID, hidden: hidden),
          AnimatedSizeAndFade(
            alignment: Alignment.topCenter,
            child: hidden
                ? const SizedBox(key: Key('wcHidden'), width: double.infinity)
                : Padding(key: const Key('wcVisible'), padding: const EdgeInsets.fromLTRB(8, 8, 8, 10), child: child),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID, required this.hidden});

  final String machineUUID;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_webcamCardControllerProvider(machineUUID).notifier);
    final themeData = Theme.of(context);

    return ListTile(
      // Keeps the leading icon centered while the hidden hint adds a second line
      titleAlignment: ListTileTitleAlignment.center,
      // InkResponse instead of IconButton to keep the same footprint as a plain leading icon
      leading: Tooltip(
        message: tr(hidden ? 'pages.dashboard.general.cam_card.show' : 'pages.dashboard.general.cam_card.hide'),
        child: InkResponse(
          onTap: controller.toggleHidden,
          radius: 20,
          child: AnimatedSwitcher(
            duration: kThemeAnimationDuration,
            // Both icons share the same outline, so a cross-fade makes it look like only the slash appears
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(anim), child: child),
            ),
            child: hidden
                ? const Icon(MaterialCommunityIcons.webcam_off, key: ValueKey('camHidden'))
                : const Icon(MaterialCommunityIcons.webcam, key: ValueKey('camVisible')),
          ),
        ),
      ),
      // The hint is part of the title instead of the subtitle, so the switch from one to two lines can be animated
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('pages.dashboard.general.cam_card.webcam').tr(),
          AnimatedSizeAndFade(
            alignment: Alignment.topLeft,
            fadeDuration: kThemeAnimationDuration,
            sizeDuration: kThemeAnimationDuration,
            child: hidden
                ? Text(
                    'pages.dashboard.general.cam_card.hidden',
                    key: const ValueKey('camHiddenHint'),
                    style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onSurfaceVariant),
                  ).tr()
                : const SizedBox(key: ValueKey('camNoHint'), width: double.infinity),
          ),
        ],
      ),
      trailing: hidden ? null : _CamSelector(machineUUID: machineUUID),
    );
  }
}

class _CamSelector extends ConsumerWidget {
  const _CamSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_webcamCardControllerProvider(machineUUID).notifier);
    var model = ref.watch(_webcamCardControllerProvider(machineUUID)).value;

    if (model == null || model.allCams.length + (model.timelapseAvailable ? 1 : 0) <= 1) {
      return const SizedBox.shrink();
    }

    return DropdownButton(
      value: model.showTimelapseFrame ? timelapseFrameIndex : model.selected,
      onChanged: controller.onSelectedChange,
      items: [
        for (var i = 0; i < model.allCams.length; i++)
          DropdownMenuItem(value: i, child: Text(beautifyName(model.allCams[i].name))),
        if (model.timelapseAvailable)
          DropdownMenuItem(
            value: timelapseFrameIndex,
            child: const Text('pages.dashboard.general.cam_card.timelapse_frame').tr(),
          ),
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

    if (model.allCams.isEmpty) return const SizedBox.shrink();

    // For the preview. This is a bit hacky but it works the best!
    if (model.activeCam.service == WebcamServiceType.preview) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SvgPicture.asset('assets/vector/undraw_video_files_fu10.svg'),
        ),
      );
    }

    if (model.showTimelapseFrame) {
      return Center(
        child: TimelapseFrameImage(
          key: const Key('wcTimelapseFrame'),
          machineUUID: machineUUID,
          placeholder: const AspectRatio(aspectRatio: 4 / 3, child: Center(child: CircularProgressIndicator())),
        ).let((it) => _imageBuilder(context, it)),
      );
    }

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
    return ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(5)), child: imageTransformed);
  }
}

@riverpod
class _WebcamCardController extends _$WebcamCardController {
  CompositeKey get _hadWebcamKey => CompositeKey.keyWithString(UiKeys.hadWebcam, machineUUID);

  CompositeKey get _hideWebcamKey => CompositeKey.keyWithString(UiKeys.hideWebcam, machineUUID);

  SettingService get _settingService => ref.read(settingServiceProvider);

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.webcamIndex, machineUUID);

  bool? _wroteValue;

  @override
  FutureOr<_Model> build(String machineUUID) {
    ref.keepAliveFor();

    talker.info('Rebuilding WebcamCardController for $machineUUID');

    final machineAsync = ref.watch(machineProvider(machineUUID));
    final allWebcamsAsync = ref.watch(allWebcamInfosProvider(machineUUID));
    final hasTimelapseComponent =
        ref.watch(klipperProvider(machineUUID).selectAs((d) => d.hasTimelapseComponent)).value == true;
    // A paused print still is a running print
    final printRunning = ref
            .watch(printerProvider(machineUUID).selectAs(
                (d) => d.print.state == PrintState.printing || d.print.state == PrintState.paused))
            .value ==
        true;
    // Only fetch the last frame if the timelapse component is available, and only rebuild if a frame exists or not
    final hasTimelapseFrame = hasTimelapseComponent &&
        printRunning &&
        ref.watch(timelapseLastFrameProvider(machineUUID).select((d) => d.value != null));

    var machine = machineAsync.requireValue;
    var allWebcams = allWebcamsAsync.requireValue;

    var readInt = _settingService.readInt(_settingsKey, 0);
    var idx = (state.whenData((value) => value.selected).value ?? readInt);

    if (allWebcams.isEmpty) {
      idx = 0;
    } else {
      idx = idx.clamp(0, allWebcams.length - 1);
    }

    if (_wroteValue != allWebcams.isNotEmpty) {
      _wroteValue = allWebcams.isNotEmpty;
      _settingService.writeBool(_hadWebcamKey, allWebcams.isNotEmpty);
    }

    // await Future.delayed(const Duration(milliseconds: 5000));

    return _Model(
      machine: machine!,
      selected: idx,
      allCams: allWebcams,
      timelapseAvailable: hasTimelapseFrame,
      // Falls back to the live cam once the print is done or no frame is available anymore
      showTimelapseFrame: hasTimelapseFrame && (state.value?.showTimelapseFrame ?? false),
    );
  }

  void onSelectedChange(int? index) {
    if (index == null) return;
    // The timelapse frame is only a temporary view during a print, therefore it is not persisted
    if (index == timelapseFrameIndex) {
      state = state.whenData((value) => value.copyWith(showTimelapseFrame: true));
      return;
    }
    state = state.whenData((value) => value.copyWith(selected: index, showTimelapseFrame: false));
    _settingService.writeInt(_settingsKey, index);
  }

  void onFullScreenTap() {
    if (!state.hasValue) return;
    var value = state.requireValue;
    ref
        .read(goRouterProvider)
        .pushNamed(AppRoute.fullCam.name, extra: {'machine': value.machine, 'selectedCam': value.activeCam});
  }

  void onRetry() {
    // this is just to make sure we recall the webcam API if that was the reason
    ref.invalidate(allWebcamInfosProvider(machineUUID));
    // ref.invalidateSelf();
  }

  void toggleHidden() {
    final hidden = !_settingService.readBool(_hideWebcamKey);
    talker.info('${hidden ? 'Hiding' : 'Showing'} Webcam Card for $machineUUID');
    _settingService.writeBool(_hideWebcamKey, hidden);
  }
}

class _WebcamCardPreviewController extends _WebcamCardController {
  @override
  FutureOr<_Model> build(String machineUUID) {
    return _Model(
      machine: Machine(uuid: Uuid().v4(), name: 'Preview Machine', httpUri: Uri()),
      selected: 0,
      allCams: [
        WebcamInfo(
          uid: 'preview',
          name: 'Preview Cam',
          service: WebcamServiceType.preview,
          streamUrl: Uri(),
          snapshotUrl: Uri(),
        ),
      ],
    );
  }

  @override
  void onSelectedChange(int? index) {
    // do nothing in preview
  }

  @override
  void onFullScreenTap() {
    // do nothing in preview
  }

  @override
  void onRetry() {
    // do nothing in preview
  }

  @override
  void toggleHidden() {
    // do nothing in preview
  }
}

@freezed
sealed class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required List<WebcamInfo> allCams,
    required int? selected,
    required Machine machine,
    // Whether the latest timelapse frame can be selected instead of a cam (timelapse component + running print)
    @Default(false) bool timelapseAvailable,
    @Default(false) bool showTimelapseFrame,
  }) = __Model;

  bool get camSelected => allCams.isNotEmpty && selected != null;

  WebcamInfo get activeCam => allCams[selected!];
}
