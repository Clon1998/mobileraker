import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart';
import 'package:mobileraker/data/model/hive/webcam_mode.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mjpeg.g.dart';

typedef StreamConnectedBuilder = Widget Function(
    BuildContext context, Widget imageTransformed);

@riverpod
MjpegConfig _mjpegConfig(_MjpegConfigRef ref) => throw UnimplementedError();

@riverpod
_MjpegManager _mjpegManager(_MjpegManagerRef ref) {
  var mjpegConfig = ref.watch(_mjpegConfigProvider);

  var manager = (mjpegConfig.mode == WebCamMode.ADAPTIVE_STREAM)
      ? _AdaptiveMjpegManager(mjpegConfig)
      : _DefaultMjpegManager(mjpegConfig);
  ref.onDispose(manager.dispose);
  return manager;
}

class Mjpeg extends ConsumerWidget {
  const Mjpeg({
    Key? key,
    required this.config,
    this.stackChild = const [],
    this.transform,
    this.fit,
    this.width,
    this.height,
    this.showFps = false,
    this.imageBuilder,
  }) : super(key: key);

  final List<Widget> stackChild;
  final Matrix4? transform;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final bool showFps;
  final StreamConnectedBuilder? imageBuilder;
  final MjpegConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        _mjpegConfigProvider.overrideWithValue(config),
        _mjpegControllerProvider,
        _mjpegManagerProvider
      ],
      child: _Mjpeg(
        stackChild: stackChild,
        showFps: showFps,
        transform: transform,
        fit: fit,
        width: width,
        height: height,
        imageBuilder: imageBuilder,
      ),
    );
  }
}

class _Mjpeg extends ConsumerWidget {
  const _Mjpeg({
    Key? key,
    required this.stackChild,
    required this.showFps,
    this.transform,
    this.fit,
    this.width,
    this.height,
    this.imageBuilder,
  }) : super(key: key);

  final List<Widget> stackChild;
  final Matrix4? transform;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final bool showFps;
  final StreamConnectedBuilder? imageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isLoading =
        ref.watch(_mjpegControllerProvider.select((value) => value.isLoading));
    bool hasError =
        ref.watch(_mjpegControllerProvider.select((value) => value.hasError));

    if (hasError) {
      var state = ref.read(_mjpegControllerProvider);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(
            height: 30,
          ),
          Text(state.error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).errorColor)),
          TextButton.icon(
              onPressed:
                  ref.read(_mjpegControllerProvider.notifier).onRetryPressed,
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('components.connection_watcher.reconnect').tr())
        ],
      );
    }

    if (isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitDancingSquare(
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(
            height: 15,
          ),
          FadingText(tr('components.connection_watcher.trying_connect'))
        ],
      );
    }

    Widget img = _TransformedImage(
      transform: transform,
      fit: fit,
      width: width,
      height: height,
    );
    return EaseIn(
      child: Stack(
        children: [
          (imageBuilder == null) ? img : imageBuilder!(context, img),
          if (showFps) const _FPSDisplay(),
          ...stackChild
        ],
      ),
    );
  }
}

class _FPSDisplay extends ConsumerWidget {
  const _FPSDisplay({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_mjpegControllerProvider.selectAs((data) => data.fps))
        .maybeWhen(
            data: (fps) {
              var themeData = Theme.of(context);
              return Positioned.fill(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                      padding: const EdgeInsets.all(4),
                      margin: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: themeData.colorScheme.secondary,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5))),
                      child: Text(
                        'FPS: ${fps.toStringAsFixed(1)}',
                        style: themeData.textTheme.bodySmall?.copyWith(
                            color: themeData.colorScheme.onSecondary),
                      )),
                ),
              );
            },
            orElse: () => const SizedBox.shrink());
  }
}

class _TransformedImage extends ConsumerWidget {
  const _TransformedImage({
    Key? key,
    this.transform,
    this.fit,
    this.width,
    this.height,
  }) : super(key: key);

  final Matrix4? transform;
  final BoxFit? fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_mjpegControllerProvider.selectAs((data) => data.image))
        .maybeWhen(
            data: (image) {
              Widget img = Image(
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
              return img;
            },
            orElse: () => const SizedBox.shrink());
  }
}

@riverpod
// 4. extend like this
class _MjpegController extends _$MjpegController with WidgetsBindingObserver {
  _MjpegController() {
    WidgetsBinding.instance.addObserver(this);
  }

  StreamSubscription? _jpegSub;

  double fps = 0;
  int _frameCnt = 0;
  DateTime? _start;

  @override
  AsyncValue<MjpegState> build() {
    var mjpegManager = ref.watch(_mjpegManagerProvider);

    _jpegSub =
        mjpegManager.jpegStream.listen(onImageData, onError: onImageDataError);

    mjpegManager.start();
    // 6. return a value (or do nothing if the return type is void)
    ref.onDispose(dispose);
    return const AsyncValue.loading();
  }

  onRetryPressed() {
    state = const AsyncValue.loading();
    ref.watch(_mjpegManagerProvider).start();
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.watch(_mjpegManagerProvider).start();
        break;

      case AppLifecycleState.paused:
        ref.watch(_mjpegManagerProvider).stop();
        break;
      default:
      // Do Nothing
    }
  }

  onImageData(MemoryImage image) {
    state = AsyncValue.data(MjpegState(image, fps));
    _frameCnt++;
    DateTime now = DateTime.now();

    if (_start == null) {
      _start = now;
      return;
    }
    var passed = now.difference(_start!).inSeconds;
    if (passed >= 1) {
      fps = _frameCnt / passed;
      _frameCnt = 0;
      _start = now;
    }
  }

  onImageDataError(Object err, StackTrace s) {
    state = AsyncValue.error(err, s);
  }

  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jpegSub?.cancel();
  }
}

@immutable
class MjpegState {
  const MjpegState(this.image, this.fps);

  final MemoryImage image;
  final double fps;
}

@immutable
class MjpegConfig {
  const MjpegConfig({
    required this.feedUri,
    this.httpHeader = const {},
    required this.mode,
    this.targetFps = 10,
    this.timeout = const Duration(seconds: 5),
  });

  final String feedUri;
  final Duration timeout;
  final Map<String, String> httpHeader;
  final int targetFps;
  final WebCamMode mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MjpegConfig &&
          runtimeType == other.runtimeType &&
          feedUri == other.feedUri &&
          timeout == other.timeout &&
          mapEquals(httpHeader, other.httpHeader) &&
          targetFps == other.targetFps &&
          mode == other.mode;

  @override
  int get hashCode =>
      feedUri.hashCode ^
      timeout.hashCode ^
      httpHeader.hashCode ^
      targetFps.hashCode ^
      mode.hashCode;
}

// feedUri, timeout, headers, targetFps, camMode

abstract class _MjpegManager {
  start();

  stop();

  dispose();

  Stream<MemoryImage> get jpegStream;
}

/// This Manager is for the normal MJPEG!
class _DefaultMjpegManager implements _MjpegManager {
  _DefaultMjpegManager(MjpegConfig config)
      : _uri = Uri.parse(config.feedUri),
        _timeout = config.timeout,
        headers = config.httpHeader;

  // Jpeg Magic Nubmers: https://www.file-recovery.com/jpg-signature-format.htm
  static const _TRIGGER = 0xFF;
  static const _SOI = 0xD8;
  static const _EOI = 0xD9;

  final Uri _uri;

  final Duration _timeout;

  final Map<String, String> headers;

  final Client _httpClient = Client();

  final StreamController<MemoryImage> _mjpegStreamController =
      StreamController();

  @override
  Stream<MemoryImage> get jpegStream => _mjpegStreamController.stream;

  StreamSubscription? _subscription;

  @override
  stop() {
    logger.i('STOPPING STREAM!');
    _subscription?.cancel();
  }

  @override
  start() async {
    _subscription?.cancel(); // Ensure its clear to start a new stream!
    try {
      final request = Request('GET', _uri);
      request.headers.addAll(headers);
      final StreamedResponse response = await _httpClient.send(request).timeout(
          _timeout); //timeout is to prevent process to hang forever in some case

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _subscription = response.stream
            .listen(_onData, onError: _onError, cancelOnError: true);
      } else {
        if (!_mjpegStreamController.isClosed) {
          _mjpegStreamController.addError(
              HttpException('Stream returned ${response.statusCode} status'),
              StackTrace.current);
        }
      }
    } catch (error, stack) {
      // we ignore those errors in case play/pause is triggers
      if (!error
          .toString()
          .contains('Connection closed before full header was received')) {
        if (!_mjpegStreamController.isClosed) {
          _mjpegStreamController.addError(error, stack);
        }
      }
    }
  }

  final BytesBuilder _byteBuffer = BytesBuilder();
  final int _lastByte = 0x00;

  _sendImage(Uint8List bytes) async {
    if (bytes.isNotEmpty && !_mjpegStreamController.isClosed) {
      _mjpegStreamController.add(MemoryImage(bytes));
    }
  }

  _onData(List<int> byteChunk) {
    if (_byteBuffer.isNotEmpty && _lastByte == _TRIGGER) {
      if (byteChunk.first == _EOI) {
        _byteBuffer.addByte(byteChunk.first);

        _sendImage(_byteBuffer.takeBytes());
      }
    }

    for (var i = 0; i < byteChunk.length; i++) {
      final int cur = byteChunk[i];
      final int next = (i != byteChunk.length - 1) ? byteChunk[i + 1] : 0x00;

      if (cur == _TRIGGER && next == _SOI) {
        // Detect start of JPEG
        _byteBuffer.addByte(_TRIGGER);
      } else if (_byteBuffer.isNotEmpty && cur == _TRIGGER && next == _EOI) {
        // Detect end of JPEG
        _byteBuffer.addByte(cur);
        _byteBuffer.addByte(next);
        _sendImage(_byteBuffer.takeBytes());
        i++;
      } else if (_byteBuffer.isNotEmpty) {
        // Prevent it from adding other than jpeg bytes
        _byteBuffer.addByte(cur);
      }
    }
  }

  _onError(error, stack) {
    try {
      if (!_mjpegStreamController.isClosed) {
        _mjpegStreamController.addError(error, stack);
      }
    } catch (ex) {}
    dispose();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _mjpegStreamController.close();

    _httpClient.close();
    logger.i('_DefaultStreamManager DISPOSED');
  }
}

/// Manager for an Adaptive MJPEG, using snapshots/images of the MJPEG provider!
class _AdaptiveMjpegManager implements _MjpegManager {
  _AdaptiveMjpegManager(MjpegConfig config)
      : _uri = Uri.parse(config.feedUri),
        headers = config.httpHeader,
        _timeout = config.timeout,
        targetFps = config.targetFps;

  final Map<String, String> headers;

  final Duration _timeout;

  final int targetFps;

  final Uri _uri;

  final Client _httpClient = Client();

  final StreamController<MemoryImage> _mjpegStreamController =
      StreamController();

  bool active = false;

  DateTime lastRefresh = DateTime.now();

  Timer? _timer;

  @override
  Stream<MemoryImage> get jpegStream => _mjpegStreamController.stream;

  int get frameTimeInMillis {
    return 1000 ~/ targetFps;
  }

  @override
  start() {
    active = true;
    logger.i('Start MJPEG - targFps: $targetFps - $_uri');
    if (_timer?.isActive ?? false) return;
    _timer = Timer(const Duration(milliseconds: 0), _timerCallback);
  }

  @override
  stop() {
    logger.i('Stop MJPEG');
    active = false;
    _timer?.cancel();
  }

  _timerCallback() async {
    // logger.i('TimerTask ${DateTime.now()}');
    try {
      Response response = await _httpClient
          .get(
              _uri.replace(queryParameters: {
                'action': 'snapshot',
                'cacheBust': lastRefresh.millisecondsSinceEpoch.toString()
              }),
              headers: headers)
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _sendImage(response.bodyBytes);
        _restartTimer();
      } else {
        if (!_mjpegStreamController.isClosed) {
          _mjpegStreamController.addError(
              HttpException('Request returned ${response.statusCode} status'),
              StackTrace.current);
        }
      }
    } catch (error, stack) {
      // we ignore those errors in case play/pause is triggers
      if (error is TimeoutException) {
        if (!_mjpegStreamController.isClosed) {
          _mjpegStreamController.addError(error, stack);
        }
      } else {
        _restartTimer();
      }
    }
  }

  _restartTimer([DateTime? stamp]) {
    stamp ??= DateTime.now();
    if (!active) return;
    int diff = stamp.difference(lastRefresh).inMilliseconds;
    int calcTimeoutMillis = frameTimeInMillis - diff;
    // logger.i('Diff: $diff\n     CalcTi: $calcTimeoutMillis');
    _timer = Timer(
        Duration(milliseconds: max(0, calcTimeoutMillis)), _timerCallback);
    lastRefresh = stamp;
  }

  _sendImage(Uint8List bytes) async {
    if (bytes.isNotEmpty && !_mjpegStreamController.isClosed && active) {
      _mjpegStreamController.add(MemoryImage(bytes));
    }
  }

  @override
  Future<void> dispose() async {
    stop();
    _mjpegStreamController.close();
    _httpClient.close();
    logger.i('_AdaptiveStreamManager DISPOSED');
  }
}
