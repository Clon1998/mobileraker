/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/overview/components/connection_state_handler.dart';
import 'package:shimmer/shimmer.dart';

// part 'printer_card.freezed.dart';
// part 'printer_card.g.dart';

class PrinterCard extends HookConsumerWidget {
  const PrinterCard(this.machine, {super.key});

  static Widget loading() {
    return const _PrinterCardLoading();
  }

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    return ConnectionStateHandler(machine: machine);
  }
}

class _PrinterCardLoading extends StatelessWidget {
  const _PrinterCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CardTitleSkeleton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
