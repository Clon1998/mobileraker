/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'components/octo_widgets.dart';

final dismissiedRemoteInfoProvider = StateProvider<bool>((ref) => false);

class RemoteConnectionIndicator extends ConsumerWidget {
  const RemoteConnectionIndicator({
    Key? key,
    required this.clientType,
  }) : super(key: key);

  final ClientType clientType;

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
        child: (ref.watch(dismissiedRemoteInfoProvider))
            ? const SizedBox.shrink()
            : Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
                      leading: clientType == ClientType.octo
                          ? const OctoIndicator()
                          : const Icon(
                              Icons.cloud,
                            ),
                      title: const Text('components.remote_connection_indicator.title').tr(),
                      trailing: IconButton(
                          onPressed: () =>
                              ref.read(dismissiedRemoteInfoProvider.notifier).state = true,
                          icon: const Icon(Icons.close)),
                    ),
                  ],
                ),
              ));
  }
}
