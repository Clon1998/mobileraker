import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

typedef StreamConnectedBuilder = Widget Function(
    BuildContext context, Transform imageTransformed);

class Mjpeg extends ViewModelBuilderWidget<MjpegViewModel> {
  final String feedUri;
  final List<Widget> stackChildren;
  final Matrix4? transform;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Duration timeout;
  final Map<String, String> headers;
  final bool showFps;
  final StreamConnectedBuilder? imageBuilder;

  const Mjpeg({
    Key? key,
    required this.feedUri,
    this.stackChildren = const [],
    this.transform,
    this.fit,
    this.width,
    this.height,
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
    this.showFps = false,
    this.imageBuilder,
  }) : super(key: key);

  @override
  MjpegViewModel viewModelBuilder(BuildContext context) =>
      MjpegViewModel(feedUri, timeout, headers);

  @override
  Widget builder(BuildContext context, MjpegViewModel model, Widget? child) {
    if (!model.isBusy) {
      if (model.hasError) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline),
            SizedBox(
              height: 30,
            ),
            Text(model.modelError.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).errorColor)),
            TextButton.icon(
                onPressed: model.onRetryPressed,
                icon: Icon(Icons.restart_alt_outlined),
                label: Text('components.connection_watcher.reconnect').tr())
          ],
        );
      } else if (model.dataReady) {
        Widget img = Image(
          image: model.data!,
          width: width,
          height: height,
          gaplessPlayback: true,
          fit: fit,
        );
        if (transform == null) {
          return img;
        } else {
          Transform transformWidget = Transform(
            alignment: Alignment.center,
            transform: transform!,
            child: img,
          );

          return EaseIn(
            child: Stack(
              children: [
                (imageBuilder == null)
                    ? transformWidget
                    : imageBuilder!(context, transformWidget),
                if (showFps)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                          padding: EdgeInsets.all(4),
                          margin: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.all(Radius.circular(5))),
                          child: Text(
                            'FPS: ${model.fps.toStringAsFixed(1)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondary),
                          )),
                    ),
                  ),
                ...stackChildren
              ],
            ),
          );
        }
      }
    }

    return Column(
      children: [
        SpinKitDancingSquare(
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(
          height: 15,
        ),
        FadingText(tr('components.connection_watcher.trying_connect'))
      ],
    );
    // if (errorState.value != null) {
    //   return SizedBox(
    //     width: width,
    //     height: height,
    //     child: error == null
    //         ? Center(
    //             child: Padding(
    //               padding: const EdgeInsets.all(8.0),
    //               child: Text(
    //                 '${errorState.value}',
    //                 textAlign: TextAlign.center,
    //                 style: TextStyle(color: Colors.red),
    //               ),
    //             ),
    //           )
    //         : error!(context, errorState.value!.first, errorState.value!.last),
    //   );
    // }

    // if (image.value == null) {
    //   return SizedBox(
    //       width: width,
    //       height: height,
    //       child: loading == null
    //           ? Center(child: CircularProgressIndicator())
    //           : loading!(context));
    // }
  }
}

class MjpegViewModel extends StreamViewModel<MemoryImage?>
    with WidgetsBindingObserver {
  final _logger = getLogger('MjpegViewModel');
  final String feedUri;
  final Duration timeout;
  final Map<String, String> headers;

  late _StreamManager _manager = _StreamManager(feedUri, headers, timeout);
  int _frameCnt = 0;
  double _lastFps = 0;

  double get fps => _lastFps;
  DateTime? _start;

  MjpegViewModel(this.feedUri, this.timeout, this.headers);

  @override
  Stream<MemoryImage> get stream => _manager.mjpegStream;

  onRetryPressed() {
    setBusy(true);
    _manager.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

  @override
  void initialise() {
    super.initialise();
    if (!initialised) {
      WidgetsBinding.instance?.addObserver(this);
      setBusy(true);
      _manager.start();
    }
  }

  @override
  void onData(MemoryImage? data) {
    setBusy(false);
    if (data != null) {
      _frameCnt++;
      DateTime now = DateTime.now();

      if (_start == null) {
        _start = now;
        return;
      }
      var passed = now.difference(_start!).inSeconds;
      if (passed >= 1) {
        _lastFps = _frameCnt / passed;
        _frameCnt = 0;
        _start = now;
      }
    }
  }

  @override
  void onError(error) {
    _logger.e('Error: $error');
    setBusy(false);
  }

  @override
  void dispose() {
    super.dispose();
    _manager.dispose();
    WidgetsBinding.instance?.removeObserver(this);
  }
}

class _StreamManager {
  final _logger = getLogger('_StreamManager');

  // Jpeg Magic Nubmers: https://www.file-recovery.com/jpg-signature-format.htm
  static const _TRIGGER = 0xFF;
  static const _SOI = 0xD8;
  static const _EOI = 0xD9;

  final String feedUri;
  final Duration _timeout;
  final Map<String, String> headers;
  final Client _httpClient = Client();

  final StreamController<MemoryImage> _mjpegStreamController =
      StreamController.broadcast();

  Stream<MemoryImage> get mjpegStream => _mjpegStreamController.stream;

  StreamSubscription? _subscription;

  _StreamManager(this.feedUri, this.headers, this._timeout);

  void stop() {
    _logger.i('STOPPING STREAM!');
    _subscription?.cancel();
  }

  void start() async {
    _subscription?.cancel(); // Ensure its clear to start a new stream!
    try {
      final request = Request("GET", Uri.parse(feedUri));
      request.headers.addAll(headers);
      final StreamedResponse response = await _httpClient.send(request).timeout(
          _timeout); //timeout is to prevent process to hang forever in some case

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _subscription = response.stream
            .listen(_onData, onError: _onError, cancelOnError: true);
      } else {
        _mjpegStreamController.addError(
            HttpException('Stream returned ${response.statusCode} status'),
            StackTrace.current);
      }
    } catch (error, stack) {
      // we ignore those errors in case play/pause is triggers
      if (!error
          .toString()
          .contains('Connection closed before full header was received')) {
        if (!_mjpegStreamController.isClosed)
          _mjpegStreamController.addError(error, stack);
      }
    }
  }

  BytesBuilder _byteBuffer = BytesBuilder();
  int _lastByte = 0x00;

  void _sendImage(Uint8List bytes) async {
    if (bytes.isNotEmpty) {
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
      _mjpegStreamController.addError(error, stack);
    } catch (ex) {}
    dispose();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _mjpegStreamController.close();

    _httpClient.close();
    _logger.i('DISPOSED');
  }
}
