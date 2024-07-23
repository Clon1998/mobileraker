/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/remote_config/developer_announcement_entry.dart';
import 'package:common/data/dto/remote_config/developer_announcement_entry_type.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/mobileraker_icon_button.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../routing/app_router.dart';
import 'adaptive_horizontal_page.dart';

part 'remote_announcements.g.dart';

@riverpod
class _RemoteAnnouncementsController extends _$RemoteAnnouncementsController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  Map<String, int> get _dismissedHashes =>
      _settingService.read(UtilityKeys.devAnnouncementDismiss, <dynamic, dynamic>{}).cast<String, int>();

  @override
  List<DeveloperAnnouncementEntry> build() {
    ref.keepAlive(); // Only show messages once per app start
    var isSupporter = ref.watch(isSupporterProvider);
    var announcement = ref.watch(developerAnnouncementProvider);
    logger.i('Developer announcements are enabled: ${announcement.enabled}');
    logger.i('Received ${announcement.messages.length} developer announcements.');
    logger.wtf('Announcements: ${announcement.messages.map((e) => e.toJson()).toList()}');
    if (!announcement.enabled) return [];

    // logger.i('Dismissed hashes: $_dismissedHashes');

    return announcement.messages
        .where((element) =>
            element.show &&
            (_dismissedHashes[element.hash] ?? 0) < element.showCount &&
            (!isSupporter || element.type != DeveloperAnnouncementEntryType.advertisement))
        .toList();
  }

  dismiss(DeveloperAnnouncementEntry entry) {
    _settingService.write(UtilityKeys.devAnnouncementDismiss, {
      ..._dismissedHashes,
      entry.hash: (_dismissedHashes[entry.hash] ?? 0) + 1,
    });
    state = state.toList()..remove(entry);
  }

  navigateToSupporterPage() {
    ref.read(goRouterProvider).pushNamed(AppRoute.supportDev.name);
  }
}

class RemoteAnnouncements extends ConsumerWidget {
  const RemoteAnnouncements({super.key, this.horizontalScroll = false});

  final bool horizontalScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MessageBoard(horizontalScroll: horizontalScroll);
  }
}

class _MessageBoard extends ConsumerWidget {
  const _MessageBoard({super.key, this.horizontalScroll = false});

  final bool horizontalScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var messages = ref.watch(_remoteAnnouncementsControllerProvider);

    logger.i('Messages to show: ${messages.length}');

    // Horizontal Version
    var children = [
      for (var message in messages) _MessageCard(key: ValueKey(message), message: message, animate: !horizontalScroll),
    ];

    if (!horizontalScroll) {
      return Column(mainAxisSize: MainAxisSize.min, children: children);
    }

    return AdaptiveHorizontalPage(
      pageStorageKey: 'asdasd',
      padding: const EdgeInsets.only(top: 8),
      // crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );

    // return Card(
    //   child: Padding(
    //     padding: const EdgeInsets.only(bottom: 8.0),
    //     child: AdaptiveHorizontalPage(
    //       pageStorageKey: 'asdasd',
    //       padding: EdgeInsets.zero,
    //       children: [
    //         for (var message in messages) _MessageCard(message: message),
    //       ],
    //     ),
    //   ),
    // );
  }
}

class _MessageCard extends HookConsumerWidget {
  const _MessageCard({super.key, required this.message, this.animate = true});

  final DeveloperAnnouncementEntry message;

  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    VoidCallback? onTap = switch (message) {
      DeveloperAnnouncementEntry(:final link?) => () => openUrl(link),
      DeveloperAnnouncementEntry(type: DeveloperAnnouncementEntryType.advertisement) =>
        ref.read(_remoteAnnouncementsControllerProvider.notifier).navigateToSupporterPage,
      _ => null,
    };

    final themeData = Theme.of(context);
    final customColors = themeData.extension<CustomColors>()!;
    final Color? borderColor = switch (message.type) {
      DeveloperAnnouncementEntryType.advertisement => themeData.colorScheme.tertiary,
      DeveloperAnnouncementEntryType.info => themeData.colorScheme.secondary,
      DeveloperAnnouncementEntryType.critical => customColors.warning,
      _ => themeData.colorScheme.primary,
    };

    /// If this property is null then [CardTheme.shape] of [ThemeData.cardTheme]
    /// is used. If that's null then the shape will be a [RoundedRectangleBorder]
    /// with a circular corner radius of 12.0 and if [ThemeData.useMaterial3] is
    /// false, then the circular corner radius will be 4.0.
    final cardTheme = themeData.cardTheme;
    final borderRadius = BorderRadius.circular(themeData.useMaterial3 ? 12.0 : 4.0);
    final shape = Border(left: BorderSide(color: borderColor ?? themeData.colorScheme.primary, width: 3)) +
        (cardTheme.shape ?? RoundedRectangleBorder(borderRadius: borderRadius));

    final animCtrl = useAnimationController(initialValue: 1, duration: kThemeAnimationDuration);

    dismissNotifcation() => ref.read(_remoteAnnouncementsControllerProvider.notifier).dismiss(message);

    final card = Card(
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap.unless(animCtrl.isAnimating),
        child: Padding(
          padding: const EdgeInsets.all(8.0) + const EdgeInsets.only(left: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(message.title, style: themeData.textTheme.labelLarge)),
                  MobilerakerIconButton(
                    padding: const EdgeInsets.all(4.0),
                    onPressed: () {
                      if (animate) {
                        animCtrl.animateTo(0).then((value) => dismissNotifcation());
                      } else {
                        dismissNotifcation();
                      }
                    }.unless(animCtrl.isAnimating),
                    icon: const Icon(Icons.close, size: 24),
                  ),
                ],
              ),
              Text(message.body, style: _bodyColor(themeData), textAlign: TextAlign.justify),
            ],
          ),
        ),
      ),
    );

    if (!animate) return card;

    return SizeTransition(
      sizeFactor: animCtrl.drive(CurveTween(curve: Curves.easeInOutCubic)),
      child: card,
    );
  }

  TextStyle? _bodyColor(ThemeData themeData) {
    var col = (themeData.useMaterial3) ? themeData.colorScheme.onSurface : themeData.textTheme.bodySmall?.color;
    return themeData.textTheme.bodyMedium?.copyWith(color: col);
  }

  void openUrl(String url) {
    launchUrlString(url, mode: LaunchMode.externalApplication).ignore();
  }
}
