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
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/animation/SizeAndFadeTransition.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../routing/app_router.dart';
import 'adaptive_horizontal_page.dart';

part 'remote_announcements.g.dart';

@riverpod
class _RemoteAnnouncementsController extends _$RemoteAnnouncementsController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  @override
  List<DeveloperAnnouncementEntry> build() {
    var isSupporter = ref.watch(isSupporterProvider);
    var announcement = ref.watch(developerAnnouncementProvider);
    logger.i('Developer announcements are enabled: ${announcement.enabled}');
    if (!announcement.enabled) return [];
    var dismissedHashes = _settingService.read(UtilityKeys.devAnnouncementDismiss, <String>[]);

    return announcement.messages
        .where((element) =>
            element.show &&
            !dismissedHashes.contains(element.hash) &&
            (!isSupporter || element.type != DeveloperAnnouncementEntryType.advertisement))
        .toList();
  }

  dismiss(DeveloperAnnouncementEntry entry) {
    var dismissedHashes = _settingService.read(UtilityKeys.devAnnouncementDismiss, <String>[]);
    // _settingService.write(UtilityKeys.devAnnouncementDismiss, [...dismissedHashes, entry.hash]);
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

    // return Column(
    //   mainAxisSize: MainAxisSize.min,
    //   children: [
    //     SingleChildScrollView(
    //       key: const PageStorageKey<String>('remoteAnnouncementsM'),
    //       controller: scrollCtrler,
    //       scrollDirection: Axis.horizontal,
    //       // physics: const BouncingScrollPhysics(),
    //       child: Row(
    //         mainAxisSize: MainAxisSize.min,
    //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    //         children: [
    //           for (var message in messages) _MessageCard(message: message),
    //         ],
    //       ),
    //     ),
    //     HorizontalScrollIndicator(
    //       controller: scrollCtrler,
    //       steps: messages.length,
    //     ),
    //   ],
    // );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({super.key, required this.message});

  final DeveloperAnnouncementEntry message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
          title: Text(message.title),
          trailing: IconButton(
            onPressed: () => ref.read(_remoteAnnouncementsControllerProvider.notifier).dismiss(message),
            icon: const Icon(Icons.close),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(message.body, style: _bodyColor(themeData)),
        ),
        if (message.type == DeveloperAnnouncementEntryType.advertisement)
          TextButton(
            onPressed: ref.read(_remoteAnnouncementsControllerProvider.notifier).navigateToSupporterPage,
            child: const Text(
              'components.supporter_only_feature.button',
              style: TextStyle(fontSize: 11),
            ).tr(),
          ),
      ],
    );
  }

  TextStyle? _bodyColor(ThemeData themeData) {
    var col = (themeData.useMaterial3) ? themeData.colorScheme.onSurface : themeData.textTheme.bodySmall?.color;
    return themeData.textTheme.bodyMedium?.copyWith(color: col);
  }
}
