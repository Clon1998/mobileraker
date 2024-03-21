/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/octoeverywhere/gadget_status.dart';
import 'package:common/service/octoeverywhere/gadget_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OctoEveryWhereBtn extends StatelessWidget {
  const OctoEveryWhereBtn({super.key, this.onPressed, required this.title});

  final VoidCallback? onPressed;
  final String title;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff7399ff),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/vector/oe_rocket.svg',
              width: 30,
              height: 30,
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      );
}

class OctoIndicator extends StatelessWidget {
  const OctoIndicator({super.key, this.size});

  final Size? size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      preferBelow: false,
      message: 'components.octo_indicator.tooltip'.tr(),
      child: SvgPicture.asset(
        'assets/vector/oe_rocket.svg',
        width: size?.width ?? 20,
        height: size?.height ?? 20,
      ),
    );
  }
}

class GadgetIndicator extends ConsumerWidget {
  const GadgetIndicator({super.key, required this.appToken, this.iconSize});

  final String appToken;
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var iconSize = this.iconSize ?? Theme.of(context).iconTheme.size ?? 20;
    return ref.watch(gadgetStatusProvider(appToken)).maybeWhen(
          data: (d) {
            if (d.state == GadgetState.disabled) {
              return const SizedBox.shrink();
            }

            return Tooltip(
              message: d.status,
              child: SvgPicture.asset(
                d.statusSvg,
                width: iconSize,
                height: iconSize,
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
        );
  }
}

extension _SvgSource on GadgetStatus {
  String get statusSvg {
    return switch (statusColor) {
      'g' => 'assets/vector/gadget/gadget_green.svg',
      'y' => 'assets/vector/gadget/gadget_yellow.svg',
      'r' => 'assets/vector/gadget/gadget_red.svg',
      _ => 'assets/vector/gadget/gadget_white.svg',
    };
  }
}
