/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_spy.g.dart';

class LocaleSpy extends ConsumerWidget {
  const LocaleSpy({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('LocaleSpy: build');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeLocaleProvider.notifier).setLocale(context.locale);
    });
    return child;
  }
}

@Riverpod(keepAlive: true)
class ActiveLocale extends _$ActiveLocale {
  @override
  Locale build() {
    ref.listenSelf((previous, next) {
      logger.i('Active locale changed from $previous to $next');
    });

    return const Locale('en');
  }

  void setLocale(Locale locale) {
    state = locale;
  }
}
