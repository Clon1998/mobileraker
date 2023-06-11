/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/ui/components/webcam/webcam_mjpeg.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcams/cam_card_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';

class CamCard extends ConsumerWidget {
  const CamCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var watch = ref.watch(camCardControllerProvider);

    bool showCard = (watch.valueOrFullNull?.activeCam != null &&
            watch.valueOrFullNull?.allCams.isNotEmpty == true) ||
        watch.hasError;

    return AnimatedSwitcher(
      switchInCurve: Curves.easeInOutBack,
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(
            opacity: anim,
            child: child,
          )),
      child: showCard
          ? Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      FlutterIcons.webcam_mco,
                    ),
                    title: const Text('pages.dashboard.general.cam_card.webcam')
                        .tr(),
                    trailing: const _Trailing(),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: watch.when(
                        data: (data) =>
                            data.allCams.isEmpty || data.activeCam == null
                                ? const SizedBox.shrink()
                                : Center(
                                    key: UniqueKey(),
                                    child: _CamCardData(data: data)),
                        error: (e, s) => Center(
                              child: Column(
                                key: UniqueKey(),
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline),
                                  const SizedBox(
                                    height: 30,
                                  ),
                                  Text(e.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                  TextButton.icon(
                                      onPressed: () => ref
                                          .read(camCardControllerProvider
                                              .notifier)
                                          .onRetry(),
                                      icon: const Icon(
                                          Icons.restart_alt_outlined),
                                      label: const Text('general.retry').tr())
                                ],
                              ),
                            ),
                        loading: () => Container(
                            alignment: Alignment.center,
                            child: const LinearProgressIndicator())),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _Trailing extends ConsumerWidget {
  const _Trailing({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var camState = ref.watch(camCardControllerProvider).valueOrFullNull;

    if (camState == null ||
        camState.allCams.length < 2 ||
        camState.activeCam == null) {
      return const SizedBox.shrink();
    }

    return DropdownButton(
        value: camState.activeCam!.uuid,
        onChanged:
            ref.read(camCardControllerProvider.notifier).onSelectedChange,
        items: camState.allCams.map((e) {
          return DropdownMenuItem(
            value: e.uuid,
            child: Text(beautifyName(e.name)),
          );
        }).toList());
  }
}

class _CamCardData extends ConsumerWidget {
  const _CamCardData({
    Key? key,
    required this.data,
  }) : super(key: key);
  final CamCardState data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var activeCam = data.activeCam;

    switch (activeCam!.service) {
      case WebcamServiceType.mjpegStreamer:
      case WebcamServiceType.mjpegStreamerAdaptive:
      case WebcamServiceType.uv4lMjpeg:
        return WebcamMjpeg(
          machine: data.machine,
          webcamInfo: activeCam,
          imageBuilder: _imageBuilder,
          showFps: true,
          stackChild: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.aspect_ratio),
                  tooltip: 'pages.dashboard.general.cam_card.fullscreen'.tr(),
                  onPressed: ref
                      .read(camCardControllerProvider.notifier)
                      .onFullScreenTap,
                ),
              ),
            ),
          ],
        );
      default:
        return Text(
            'Sorry... the webcam type "${activeCam.service}" is not yet supported!');
    }
  }

  Widget _imageBuilder(BuildContext context, Widget imageTransformed) {
    return ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        child: imageTransformed);
  }
}
