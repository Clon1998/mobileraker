import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'supporter_ad.g.dart';

@riverpod
class _SupporterAdController extends _$SupporterAdController {
  late final _boxSettings = Hive.box('settingsbox');

  static const _key = 'supporter_add';

  @override
  bool build() {
    var isSupporter = ref
            .watch(customerInfoProvider)
            .valueOrFullNull
            ?.entitlements
            .active
            .isNotEmpty ??
        false;

    if (isSupporter) return false;

    DateTime? stamp = _boxSettings.get(_key);

    return stamp == null || DateTime.now().difference(stamp).inDays > 25;
  }

  dismiss() {
    _boxSettings.put(_key, DateTime.now());
    state = false;
  }
}

class SupporterAd extends ConsumerWidget {
  const SupporterAd({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
        duration: kThemeAnimationDuration,
        switchInCurve: Curves.easeInCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              child: FadeTransition(
                opacity: anim,
                child: child,
              ),
            ),
        child: (ref.watch(_supporterAdControllerProvider))
            ? Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(top: 3, left: 16, right: 16),
                      leading:
                          const Icon(FlutterIcons.hand_holding_heart_faw5s),
                      title: Text('Like the app?'),
                      subtitle:
                          Text('Learn how you can support the developement!'),
                      trailing: IconButton(
                          onPressed: ref
                              .read(_supporterAdControllerProvider.notifier)
                              .dismiss,
                          icon: const Icon(Icons.close)),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink());
  }
}
