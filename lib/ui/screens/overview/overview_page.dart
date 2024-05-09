/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:progress_indicators/progress_indicators.dart';

import 'components/printer_card.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'pages.overview.title',
            overflow: TextOverflow.fade,
          ).tr(),
        ),
        body: const _OverviewBody(),
        drawer: const NavigationDrawerWidget(),
      );
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(allMachinesProvider).when<Widget>(
          data: (d) => _Data(machines: d),
          error: (e, s) {
            logger.e('Error in OverView', e, StackTrace.current);
            throw e;
          },
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpinKitRipple(
                  color: Theme.of(context).colorScheme.secondary,
                  size: 100,
                ),
                const SizedBox(height: 30),
                FadingText(tr('pages.overview.fetching_machines')),
                // Text('Fetching printer ...')
              ],
            ),
          ),
        );
  }
}

class _Data extends ConsumerWidget {
  const _Data({super.key, required this.machines});

  final List<Machine> machines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        if (context.isLargerThanMobile)
          SliverAlignedGrid.count(
            crossAxisCount: 3,
            itemCount: machines.length,
            itemBuilder: (context, index) => SinglePrinterCard(machines[index]),
          ),
        if (context.isMobile)
          SliverList.builder(
            itemCount: machines.length,
            itemBuilder: (context, index) => SinglePrinterCard(machines[index]),
          ),
        SliverToBoxAdapter(
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () => ref.read(goRouterProvider).pushNamed(AppRoute.printerAdd.name),
              icon: const Icon(Icons.add),
              label: const Text('pages.overview.add_machine').tr(),
            ),
          ),
        ),
      ],
    );
  }
}
