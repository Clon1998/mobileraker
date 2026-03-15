/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/connection/client_type_indicator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_connection_active_card.g.dart';


class RemoteConnectionActiveCard extends ConsumerWidget {
  const RemoteConnectionActiveCard({super.key, required this.machineId});

  final String machineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientType = ref.watch(jrpcClientTypeProvider(machineId));
    final dismissed = ref.watch(_controllerProvider);
    final controller = ref.read(_controllerProvider.notifier);

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeInCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: (clientType == ClientType.local || dismissed)
          ? const SizedBox.shrink()
          : Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
                    leading: MachineActiveClientTypeIndicator(
                      machineId: machineId,
                    ),
                    title: const Text(
                      'components.remote_connection_indicator.title',
                    ).tr(),
                    trailing: IconButton(
                      onPressed: controller.dismiss,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


@Riverpod(keepAlive: true)
class _Controller extends _$Controller {
  @override
  bool build() => false;

  void dismiss() {
    state = true;
  }
}
