/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/obico_widgets.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';

class MachineActiveClientTypeIndicator extends ConsumerWidget {
  const MachineActiveClientTypeIndicator({
    super.key,
    this.localIndicator,
    this.machineId,
    this.iconColor,
    this.iconSize,
  });

  final String? machineId;
  final Color? iconColor;
  final double? iconSize;
  final Widget? localIndicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var clientType = machineId?.let((it) => ref.watch(jrpcClientTypeProvider(it))) ?? ClientType.local;
    return ClientTypeIndicator(
      localIndicator: localIndicator,
      clientType: clientType,
      iconColor: iconColor,
      iconSize: iconSize,
    );
  }
}

class ClientTypeIndicator extends StatelessWidget {
  const ClientTypeIndicator({
    super.key,
    required this.clientType,
    this.localIndicator,
    this.iconColor,
    this.iconSize,
  });

  final ClientType clientType;
  final Color? iconColor;
  final double? iconSize;
  final Widget? localIndicator;

  @override
  Widget build(BuildContext context) {
    var iconSize = this.iconSize ?? Theme.of(context).iconTheme.size;

    var size = iconSize?.let(Size.square);

    return switch (clientType) {
      ClientType.local => localIndicator ?? const SizedBox.shrink(),
      ClientType.octo => OctoIndicator(size: size),
      ClientType.obico => ObicoIndicator(size: size),
      ClientType.manual || _ => Tooltip(
          message: tr('components.ri_indicator.tooltip'),
          child: Icon(Icons.cloud, color: iconColor, size: iconSize),
        ),
    };
  }
}
