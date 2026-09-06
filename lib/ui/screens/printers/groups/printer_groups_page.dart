/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';

class PrinterGroupsPage extends ConsumerWidget {
  const PrinterGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSupporter = ref.watch(isSupporterProvider);

    Widget body = isSupporter
        ? const _GroupList()
        : Center(
            child: SupporterOnlyFeature(
              text: const Text('components.supporter_only_feature.printer_groups').tr(),
            ),
          );

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('pages.printer_groups.title').tr()),
      drawer: const NavigationDrawerWidget(),
      floatingActionButton: isSupporter
          ? FloatingActionButton(
              onPressed: () => context.pushNamed(AppRoute.printerGroupEdit.name),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(child: body),
    );
  }
}

class _GroupList extends ConsumerWidget {
  const _GroupList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(printerGroupsProvider);

    return groups.when(
      data: (data) {
        if (data.isEmpty) return const _EmptyState();
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, i) => _GroupTile(group: data[i]),
        );
      },
      error: (e, s) => Center(child: Text(e.toString())),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspaces_outline, size: 64, color: themeData.disabledColor),
            const SizedBox(height: 12),
            Text(
              'pages.printer_groups.empty_hint',
              textAlign: TextAlign.center,
              style: themeData.textTheme.bodyMedium,
            ).tr(),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  const _GroupTile({required this.group});

  final PrinterGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMachines = ref.watch(allMachinesProvider).value ?? const <Machine>[];
    final members = group.machineUUIDs
        .map((uuid) => allMachines.firstWhereOrNull((m) => m.uuid == uuid))
        .whereType<Machine>()
        .toList();

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.workspaces_outline)),
      title: Text(group.name),
      subtitle: Text(
        members.isEmpty
            ? tr('pages.printer_groups.no_printers')
            : members.map((m) => m.name).join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _onDelete(context, ref),
      ),
      onTap: () => context.pushNamed(AppRoute.printerGroupEdit.name, extra: group),
    );
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final dialogService = ref.read(dialogServiceProvider);
    final result = await dialogService.showDangerConfirm(
      title: tr('pages.printer_groups.delete_dialog.title'),
      body: tr('pages.printer_groups.delete_dialog.body', args: [group.name]),
      actionLabel: tr('general.delete'),
    );

    if (result?.confirmed == true) {
      await ref.read(printerGroupServiceProvider).delete(group);
    }
  }
}
