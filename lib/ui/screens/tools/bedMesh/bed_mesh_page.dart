/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bed_mesh/bed_mesh_plot.dart';

import '../../../components/bed_mesh/bed_mesh_legend.dart';

part 'bed_mesh_page.freezed.dart';

@freezed
class BedMeshPageArgs with _$BedMeshPageArgs {
  const factory BedMeshPageArgs({
    required BedMesh bedMesh,
    required (double, double) bedMin,
    required (double, double) bedMax,
    required bool isProbed,
  }) = _BedMeshPageArgs;
}

class BedMeshPage extends HookConsumerWidget {
  const BedMeshPage({super.key, required this.args});

  final BedMeshPageArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final showProbed = useState(args.isProbed);

    var numberFormat = NumberFormat('0.000mm', context.locale.toStringWithSeparator());
    var valueRange = showProbed.value ? args.bedMesh.zValueRangeProbed : args.bedMesh.zValueRangeMesh;
    var range = numberFormat.format((valueRange.$2 - valueRange.$1));
    final activeMeshName = args.bedMesh.profileName ?? tr('general.none');

    Widget body = ResponsiveLimit(
      child: Column(
        spacing: 4,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Tooltip(
                    message: activeMeshName,
                    child: Text(
                      activeMeshName,
                      style: themeData.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Spacer(),
                Tooltip(
                  message: tr('pages.dashboard.control.bed_mesh_card.range_tooltip'),
                  child: Chip(
                    label: Text(range),
                    avatar: const Icon(
                      FlutterIcons.unfold_less_horizontal_mco,
                      // FlutterIcons.flow_line_ent,
                      // color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Hero(
            tag: 'bed_mesh_plot',
            child: BedMeshPlot(
              bedMesh: args.bedMesh,
              bedMin: args.bedMin,
              bedMax: args.bedMax,
              isProbed: showProbed.value,
              interactive: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => showProbed.value = !showProbed.value,
                  child: Tooltip(
                    message: tr(
                      'pages.dashboard.control.bed_mesh_card.showing_matrix',
                      gender: showProbed.value ? 'probed' : 'mesh',
                    ),
                    child: Hero(
                      tag: 'bed_mesh_mode_icon',
                      child: AnimatedSwitcher(
                        duration: kThemeAnimationDuration,
                        child: (showProbed.value
                            ? Icon(
                                Icons.blur_on,
                                key: const ValueKey('probed'),
                                size: 30,
                                color: themeData.colorScheme.secondary,
                              )
                            : Icon(
                                Icons.grid_on,
                                key: const ValueKey('mesh'),
                                size: 30,
                                color: themeData.colorScheme.secondary,
                              )),
                      ),
                    ),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: Hero(
                    tag: 'bed_mesh_legend',

                    child: BedMeshLegend(
                      valueRange: showProbed.value ? args.bedMesh.zValueRangeProbed : args.bedMesh.zValueRangeMesh,
                      axis: Axis.horizontal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      // ToDo: Add action for switching profiles
      appBar: AppBar(title: Text(tr('pages.dashboard.control.bed_mesh_card.title'))),
      body: body,
    );
  }
}
