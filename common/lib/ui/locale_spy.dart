/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../service/setting_service.dart';

part 'locale_spy.g.dart';

class LocaleSpy extends ConsumerWidget {
  const LocaleSpy({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeLocaleProvider.notifier).setLocale(context.locale);
    });
    return child;
  }
}

@Riverpod(keepAlive: true)
class ActiveLocale extends _$ActiveLocale {
  SettingService get _settingService => ref.read(settingServiceProvider);

  @override
  Locale build() {
    ref.listenSelf((previous, next) {
      logger.i('Active locale changed from $previous to $next');
      _settingService.writeString(UtilityKeys.lastLocale, next.toString());
    });

    final last = ref.read(stringSettingProvider(UtilityKeys.lastLocale))!;

    var split = last.split('_');

    return Locale(split[0], split.elementAtOrNull(2) ?? split.elementAtOrNull(1));
  }

  void setLocale(Locale locale) {
    state = locale;
  }
}
