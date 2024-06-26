/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/misc_providers.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/fft_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'belt_tuner.g.dart';

class BeltTuner extends HookWidget {
  const BeltTuner({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);

    var target = useState((110, 150));

    updateTarget(int f, int l) => target.value = (f, l);

    return Scaffold(
      appBar: AppBar(title: const Text('pages.beltTuner.title').tr()),
      body: SafeArea(
        child: Center(
          child: ResponsiveLimit(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints.loose(const Size(300, 300)),
                      child: SvgPicture.asset(
                        'assets/vector/undraw_settings_re_b08x.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Text(
                    'pages.beltTuner.description',
                    textAlign: TextAlign.justify,
                    style: themeData.textTheme.bodySmall,
                  ).tr(),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PeakFrequency(
                      targetFrequency: target.value.$1.toDouble(),
                    ),
                  ),
                  Text('pages.beltTuner.target', style: themeData.textTheme.bodySmall)
                      .tr(args: [target.value.$1.toString(), target.value.$2.toString()]),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'pages.beltTuner.beltType',
                      style: themeData.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ).tr(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => updateTarget(110, 150),
                        child: const Text('6mm'),
                      ),
                      TextButton(
                        onPressed: () => updateTarget(140, 150),
                        child: const Text('9mm'),
                      ),
                    ],
                  ),
                  const Spacer(),
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
                        const TextSpan(text: '. Please use with caution.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeakFrequency extends HookConsumerWidget {
  const _PeakFrequency({super.key, this.targetFrequency = 110})
      : maxPeak = targetFrequency + 25,
        minPeak = targetFrequency - 25,
        range = 50;

  final double targetFrequency;
  final double range;
  final double minPeak;
  final double maxPeak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    var peakFrequency = ref.watch(_beltTunerControllerProvider);
    var controller = ref.watch(_beltTunerControllerProvider.notifier);

    var showLoading = peakFrequency.isLoading || peakFrequency.hasError || !peakFrequency.hasValue;

    var animController = useAnimationController(duration: const Duration(milliseconds: 700));
    useEffect(
      () {
        if (showLoading) {
          animController.repeat(reverse: true);
        } else {
          animController.stop();
        }
        return null;
      },
      [controller, showLoading],
    );
    var animValue = useAnimation(animController);

    double peak;
    if (showLoading) {
      peak = minPeak + range * .2 + animValue * range * .6;
      // peak = 70 + animValue * 80;
    } else {
      peak = peakFrequency.value?.clamp(minPeak, maxPeak).toDouble() ?? minPeak;
    }

    return Column(
      children: [
        WarningCard(
          show: ref
                  .watch(permissionStatusProvider(Permission.microphone).selectAs((data) => !data.isGranted))
                  .valueOrNull ==
              true,
          title: const Text('pages.beltTuner.permissionWarning.title').tr(),
          subtitle: const Text('pages.beltTuner.permissionWarning.subtitle').tr(),
          leadingIcon: const Icon(Icons.mic_off),
          onTap: controller.requestPermission,
        ),
        Text(
          '${showLoading ? '--' : peakFrequency.requireValue.toString()} HZ',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        LinearGauge(
          // enableGaugeAnimation: true,
          // animationDuration: 1500,
          // animationGap: 0.5,
          start: minPeak,
          end: maxPeak,
          pointers: [
            Pointer(
              value: peak,
              shape: PointerShape.rectangle,
              height: 45,
              width: 4,
              pointerAlignment: PointerAlignment.center,
              enableAnimation: false,
            ),
          ],
          linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
            thickness: 30,
            linearGradient: LinearGradient(
              colors: [Colors.red, Colors.green, Colors.red],
              stops: [0.2, 0.5, 0.8],
            ),
            borderRadius: 0,
          ),
          steps: 1,
          rulers: RulerStyle(
            rulerPosition: RulerPosition.center,
            showLabel: false,
            primaryRulersHeight: 30,
            primaryRulersWidth: 2,
            showSecondaryRulers: false,
            primaryRulerColor: themeData.scaffoldBackgroundColor,
          ),
        ),
        // TextButton(onPressed: controller.start, child: const Text('START')),
      ],
    );
  }
}

@riverpod
class _BeltTunerController extends _$BeltTunerController {
  final _fftService = FftService();

  @override
  Stream<int> build() async* {
    var status = await ref.watch(permissionStatusProvider(Permission.microphone).future);
    // We can only use the fft service if we have permission to access the microphone
    if (!status.isGranted) return;

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
    start();
    yield* _fftService.peakFrequencyStream;
  }

  Future<void> requestPermission() async {
    var status = await ref.read(permissionStatusProvider(Permission.microphone).future);
    if (status.isGranted) return;
    logger.i('Mic permission is not granted ($status), requesting it now');

    if (status == PermissionStatus.denied) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      await openAppSettings();
    }

    ref.invalidate(permissionStatusProvider(Permission.microphone));
    ref.invalidateSelf();
  }

  stop() {
    _fftService.stop();
  }

  start() async {
    var status = await ref.read(permissionStatusProvider(Permission.microphone).future);
    logger.e(status);
    if (!status.isGranted) return;
    _fftService.start();
  }
}
