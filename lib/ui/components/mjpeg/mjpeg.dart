/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/mjpeg/mjpeg_manager.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

import 'mjpeg_config.dart';

part 'mjpeg.freezed.dart';
part 'mjpeg.g.dart';

typedef MjpegImageBuilder = Widget Function(
  BuildContext context,
  Widget imageTransformed,
);

class Mjpeg extends ConsumerWidget {
  const Mjpeg({
    super.key,
    required this.dio,
    required this.config,
    this.stackChild = const [],
    this.fit,
    this.width,
    this.height,
    this.showFps = false,
    this.imageBuilder,
  });

  final Dio dio;
  final MjpegConfig config;
  final List<Widget> stackChild;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final bool showFps;
  final MjpegImageBuilder? imageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = _mjpegControllerProvider(dio, config);
    var controller = ref.watch(provider.notifier);

    // return Placeholder();

    return AsyncGuard(
      debugLabel: 'Mjpeg-${config.streamUri}',
      animate: true,
      toGuard: provider.selectAs((data) => true),
      childOnError: (error, _) => _ErrorWidget(
        config: config,
        error: error,
        onRetryPressed: controller.onRetryPressed,
      ),
      childOnLoading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SpinKitDancingSquare(
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 15),
          FadingText(tr('components.connection_watcher.trying_connect')),
        ],
      ),
      childOnData: Builder(builder: (ctx) {
        Widget img = _TransformedImage(
          provider: provider,
          transform: config.transformation,
          rotation: config.rotation,
          fit: fit,
          width: width,
          height: height,
        );

        return Stack(
          children: [
            (imageBuilder == null) ? img : imageBuilder!(ctx, img),
            if (showFps) _FPSDisplay(provider: provider),
            ...stackChild,
          ],
        );
      }),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({
    super.key,
    required this.config,
    this.error,
    this.onRetryPressed,
  });

  final MjpegConfig config;
  final Object? error;
  final VoidCallback? onRetryPressed;

  @override
  Widget build(BuildContext context) {
    // TODO: Decide if we want to show error specific messages

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(height: 30),
        Text('WebCam streamURI: ${config.streamUri.obfuscate()}'),
        if (config.snapshotUri != null) Text('WebCam snapshotURI: ${config.snapshotUri!.obfuscate()}'),
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton.icon(
          onPressed: onRetryPressed,
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('components.connection_watcher.reconnect').tr(),
        ),
      ],
    );
  }
}

class _TransformedImage extends ConsumerWidget {
  const _TransformedImage({
    super.key,
    required this.provider,
    this.rotation = 0,
    this.transform,
    this.fit,
    this.width,
    this.height,
  });

  final _MjpegControllerProvider provider;
  final int rotation;
  final Matrix4? transform;
  final BoxFit? fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provider.selectAs((data) => data.image)).maybeWhen(
          data: (image) {
            Widget img = Image(
              semanticLabel: 'WebCam Image',
              image: image,
              width: width,
              height: height,
              gaplessPlayback: true,
              fit: fit,
            );
            if (transform != null) {
              img = Transform(
                alignment: Alignment.center,
                transform: transform!,
                child: img,
              );
            }
            if (rotation == 0) return img;

            return RotatedBox(
              quarterTurns: 1 * rotation ~/ 90,
              child: img,
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _FPSDisplay extends ConsumerWidget {
  const _FPSDisplay({super.key, required this.provider});

  final _MjpegControllerProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
    return ref.watch(provider.selectAs((data) => data.fps)).maybeWhen(
          data: (fps) {
            var themeData = Theme.of(context);
            return Positioned.fill(
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: themeData.colorScheme.secondary,
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                  ),
                  child: Text(
                    'FPS: ${numberFormat.format(fps)}',
                    style: themeData.textTheme.bodySmall?.copyWith(
                      color: themeData.colorScheme.onSecondary,
                    ),
                  ),
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

@riverpod
class _MjpegController extends _$MjpegController with WidgetsBindingObserver {
  _MjpegController() {
    WidgetsBinding.instance.addObserver(this);
  }

  double _fps = 0;

  int _fpsFrameCount = 0;

  DateTime _fpsLastUpdate = DateTime.now();

  MjpegManager get _manager => ref.read(mjpegManagerProvider(dio, config));

  @override
  Stream<_Model> build(Dio dio, MjpegConfig config) async* {
    // await Future.delayed(const Duration(seconds: 15));

    ref.onDispose(dispose);
    var manager = ref.watch(mjpegManagerProvider(dio, config));
    manager.start();
    yield* manager.jpegStream.doOnData(_frameReceived).map((event) => _Model(fps: _fps, image: event));
  }

  onRetryPressed() {
    state = const AsyncValue.loading();
    logger.i('Retrying Mjpeg Connection');
    _manager.start();
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _manager.start();
        break;

      case AppLifecycleState.paused:
        _manager.stop();
        break;
      default:
      // Do Nothing
    }
  }

  void _frameReceived(MemoryImage image) {
    final DateTime now = DateTime.now();
    _fpsFrameCount++;
    final int passed = now.difference(_fpsLastUpdate).inSeconds;
    if (passed >= 1) {
      _fps = _fpsFrameCount / passed;
      _fpsFrameCount = 0;
      _fpsLastUpdate = now;
    }
  }

  dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({required MemoryImage image, required double fps}) = __Model;
}
