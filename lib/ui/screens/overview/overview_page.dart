/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/ui/components/drawer/nav_drawer_view.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card.dart';
import 'package:progress_indicators/progress_indicators.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({Key? key}) : super(key: key);

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
  const _OverviewBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(allMachinesProvider).when<Widget>(
          data: (d) {
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...d.map((machine) => SinglePrinterCard(machine)),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => ref
                          .read(goRouterProvider)
                          .pushNamed(AppRoute.printerAdd.name),
                      icon: const Icon(Icons.add),
                      label: const Text('pages.overview.add_machine').tr(),
                    ),
                  ),
                ],
              ),
            );
          },
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
