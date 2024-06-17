/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'components/printer_card.dart';

part 'overview_page.g.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget body = const _OverviewBody();
    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'pages.overview.title',
          overflow: TextOverflow.fade,
        ).tr(),
      ),
      body: body,
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class _OverviewBody extends HookConsumerWidget {
  const _OverviewBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_overviewPageControllerProvider).when<Widget>(
          skipLoadingOnReload: true,
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
      // shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      slivers: [
        if (context.isLargerThanCompact)
          SliverAlignedGrid.count(
            crossAxisCount: 3,
            itemCount: machines.length,
            itemBuilder: (context, index) => PrinterCard(machines[index]),
          ),
        if (context.isCompact)
          SliverReorderableList(
            itemCount: machines.length,
            itemBuilder: (context, index) {
              final machine = machines[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(machine.uuid),
                index: index,
                child: PrinterCard(machine),
              );
            },
            onReorder: ref.read(_overviewPageControllerProvider.notifier).onReorder,
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

@riverpod
class _OverviewPageController extends _$OverviewPageController {
  MachineService get _machineService => ref.read(machineServiceProvider);

  @override
  FutureOr<List<Machine>> build() async {
    final all = await ref.watch(allMachinesProvider.future);
    return all;
  }

  void onReorder(int oldIndex, int newIndex, [bool adjust = true]) {
    if (oldIndex < newIndex && adjust) {
      newIndex -= 1;
    }

    // .reordered(oldIndex, newIndex);
    logger.i('Reordering $oldIndex -> $newIndex');
    state = state.whenData((old) {
      final n = [...old];
      return n..insert(newIndex, n.removeAt(oldIndex));
    });
    final machineUUID = state.requireValue.elementAt(oldIndex).uuid;
    _machineService.reordered(machineUUID, oldIndex, newIndex);
  }

  @override
  bool updateShouldNotify(AsyncValue<List<Machine>> previous, AsyncValue<List<Machine>> next) {
    return previous.isLoading != next.isLoading ||
        previous.hasValue != next.hasValue ||
        previous.error != next.error ||
        previous.stackTrace != next.stackTrace ||
        previous.valueOrNull?.length != next.valueOrNull?.length;
  }
}
