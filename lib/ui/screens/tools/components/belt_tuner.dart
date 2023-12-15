/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/service/misc_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/fft_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'belt_tuner.g.dart';

class BeltTuner extends ConsumerWidget {
  const BeltTuner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belt Tuner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints.loose(const Size(256, 256)),
                child: SvgPicture.asset(
                  'assets/vector/undraw_settings_re_b08x.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Text(
              'Proper belt tension is crucial for 3D printers. Belts that are too tight (or too loose) can cause mechanical issues, premature wear, and print quality issues.',
              textAlign: TextAlign.justify,
              style: themeData.textTheme.bodyMedium,
            ),
            const SizedBox(
              height: 4,
            ),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select your belt type:',
                  style: themeData.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                )),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: null, child: Text('6mm')),
                TextButton(onPressed: null, child: Text('9mm')),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _PeakFrequency(),
            ),
            Text('Target: 110 Hz over 150mm', style: themeData.textTheme.bodySmall),
            Spacer(),
            Text.rich(
              TextSpan(
                text: 'This tool is still in development and based on the ',
                style: themeData.textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: 'Voron Design tuning guide',
                    style: TextStyle(color: themeData.colorScheme.secondary),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        // Open the Voron documentation link
                        // Example: launch('https://vorondesign.com/');
                        const String url =
                            'https://docs.vorondesign.com/tuning/secondary_printer_tuning.html#belt-tension';
                        if (await canLaunchUrlString(url)) {
                          await launchUrlString(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          throw 'Could not launch $url';
                        }
                      },
                  ),
                  TextSpan(
                    text: '. Please use with caution.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeakFrequency extends HookConsumerWidget {
  const _PeakFrequency({super.key});

  static const maxPeak = 220.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var peakFrequency = ref.watch(_beltTunerControllerProvider);
    var controller = ref.watch(_beltTunerControllerProvider.notifier);

    var showLoading = peakFrequency.isLoading || peakFrequency.hasError || !peakFrequency.hasValue;

    var animController = useAnimationController(duration: const Duration(milliseconds: 700));
    useEffect(() {
      if (showLoading) {
        animController.repeat(reverse: true);
      } else {
        animController.stop();
      }
    }, [controller, showLoading]);
    var animValue = useAnimation(animController);

    double peak;
    if (showLoading) {
      peak = maxPeak / 4 + animValue * maxPeak / 2;
      // peak = 70 + animValue * 80;
    } else {
      peak = min(maxPeak, peakFrequency.value?.toDouble() ?? 0);
    }

    return Column(
      children: [
        Text(
          '${showLoading ? '--' : peakFrequency.value!.toString()} HZ',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        LinearGauge(
          // enableGaugeAnimation: true,
          // animationDuration: 1500,
          // animationGap: 0.5,
          end: maxPeak,
          pointers: [
            Pointer(
              value: peak,
              shape: PointerShape.rectangle,
              height: 45,
              width: 4,
              pointerAlignment: PointerAlignment.center,
              enableAnimation: false,
            )
          ],
          linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
            thickness: 30,
            linearGradient: LinearGradient(colors: [Colors.red, Colors.green, Colors.red]),
            borderRadius: 0,
          ),
          steps: 4,
          rulers: RulerStyle(
              rulerPosition: RulerPosition.center,
              showLabel: false,
              primaryRulersHeight: 30,
              primaryRulersWidth: 2,
              showSecondaryRulers: false,
              primaryRulerColor: Colors.white),
        ),
        // TextButton(onPressed: controller.start, child: const Text('START')),
      ],
    );
  }
}

class _PeakFrequencyLoading extends HookWidget {
  const _PeakFrequencyLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var controller = useAnimationController(duration: const Duration(milliseconds: 500));
    useEffect(() {
      controller.repeat(reverse: true);
    }, [controller]);

    var animValue = useAnimation(controller);

    return Column(
      children: [
        const Text(
          '-- HZ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        LinearGauge(
          enableGaugeAnimation: false,
          // animationDuration: 1500,
          end: 220,
          pointers: [
            Pointer(
              enableAnimation: false,
              value: 70 + animValue * 80,
              shape: PointerShape.rectangle,
              height: 50,
              width: 5,
              pointerAlignment: PointerAlignment.center,
            )
          ],
          linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
            thickness: 30,
            linearGradient: LinearGradient(colors: [Colors.red, Colors.green, Colors.red]),
            borderRadius: 0,
          ),
          steps: 4,
          rulers: RulerStyle(
              rulerPosition: RulerPosition.center,
              showLabel: false,
              primaryRulersHeight: 30,
              primaryRulersWidth: 2,
              showSecondaryRulers: false,
              primaryRulerColor: Colors.white),
        ),
      ],
    );
  }
}

@riverpod
class _BeltTunerController extends _$BeltTunerController {
  final _fftService = FftService();

  @override
  Stream<int> build() async* {
    // await Future.delayed(const Duration(seconds: 500));

    ref.listen(appLifecycleProvider, (previous, next) {
      switch (next) {
        case AppLifecycleState.resumed:
          _fftService.start();
          break;
        case AppLifecycleState.paused:
          _fftService.stop();
          break;
        default:
        // do nothing
      }
    });

    ref.onDispose(() {
      _fftService.dispose();
    });
    _fftService.start();

    yield* _fftService.peakFrequencyStream;
  }

  stop() {
    _fftService.stop();
  }

  start() {
    _fftService.start();
  }
}
