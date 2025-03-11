/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:keep_screen_on/keep_screen_on.dart';

class KeepScreenOnTrigger extends ConsumerStatefulWidget {
  const KeepScreenOnTrigger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState createState() => _KeepScreenOnTriggerState();
}

class _KeepScreenOnTriggerState extends ConsumerState<KeepScreenOnTrigger> {
  ProviderSubscription? _providerSubscription;

  @override
  void initState() {
    super.initState();
    _providerSubscription = ref.listenManual(
      boolSettingProvider(AppSettingKeys.keepScreenOn, false),
      (_, val) {
        logger.i('Keep screen on: $val');
        if (val) {
          logger.i('User requested to keep screen on at all times');
          KeepScreenOn.turnOn();
        } else {
          logger.i('User requested to NOT keep screen on at all times');
          KeepScreenOn.turnOff();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    super.dispose();
    _providerSubscription?.close();
    logger.i('Dispose KeepScreenOnTrigger, disabled keep screen on');
    KeepScreenOn.turnOff();
  }
}
