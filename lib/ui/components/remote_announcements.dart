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
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    var isSupporter = ref.watch(isSupporterProvider);
    var announcement = ref.watch(developerAnnouncementProvider);
    logger.i('Developer announcements are enabled: ${announcement.enabled}');
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
  const RemoteAnnouncements({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(_remoteAnnouncementsControllerProvider);
    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeInCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => SizeAndFadeTransition(sizeAndFadeFactor: anim, child: child),
      child: (model.isNotEmpty) ? _MessageBoard(messages: model) : const SizedBox.shrink(),
    );
  }
}

class _MessageBoard extends HookWidget {
  const _MessageBoard({super.key, required this.messages});

  final List<DeveloperAnnouncementEntry> messages;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: AdaptiveHorizontalPage(
          pageStorageKey: 'asdasd',
          padding: EdgeInsets.zero,
          children: [
            for (var message in messages) _MessageCard(message: message),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({super.key, required this.message});

  final DeveloperAnnouncementEntry message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    var isAd = message.type == DeveloperAnnouncementEntryType.advertisement;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: isAd ? ref.read(_remoteAnnouncementsControllerProvider.notifier).navigateToSupporterPage : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(message.title, style: themeData.textTheme.labelLarge),
                IconButton(
                  onPressed: () => ref.read(_remoteAnnouncementsControllerProvider.notifier).dismiss(message),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(message.body, style: _bodyColor(themeData), textAlign: TextAlign.justify),
          ],
        ),
      ),
    );
  }

  TextStyle? _bodyColor(ThemeData themeData) {
    var col = (themeData.useMaterial3) ? themeData.colorScheme.onSurface : themeData.textTheme.bodySmall?.color;
    return themeData.textTheme.bodyMedium?.copyWith(color: col);
  }
}
