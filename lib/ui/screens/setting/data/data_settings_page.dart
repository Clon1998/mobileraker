/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:io';

import 'package:common/data/dto/app_data_export.dart';
import 'package:common/data/repository/dashboard_layout_hive_repository.dart';
import 'package:common/data/repository/machine_hive_repository.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/ui/dashboard_layout_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class DataSettingsPage extends ConsumerWidget {
  const DataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = const _Body();

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('pages.setting.data.title').tr()),
      body: SafeArea(child: body),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    return Center(
      child: ResponsiveLimit(
        child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: <Widget>[
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('pages.setting.data.export.title').tr(),
              subtitle: Text('pages.setting.data.export.helper').tr(),
              leading: Icon(FlutterIcons.database_export_mco),
              // trailing: Icon(Icons.keyboard_arrow_right),
              onTap: () => onExportTap(ref, context),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('pages.setting.data.import.title').tr(),
              subtitle: Text('pages.setting.data.import.helper').tr(),
              leading: Icon(FlutterIcons.database_import_mco),
              // trailing: Icon(Icons.keyboard_arrow_right),
              onTap: () => onImportTap(ref, context),
            ),
            // Divider(),
          ],
        ),
      ),
    );
  }

  void onExportTap(WidgetRef ref, BuildContext context) async {
    var machineRepository = ref.read(machineRepositoryProvider);
    var dashboardLayoutService = ref.read(dashboardLayoutServiceProvider);
    var versionInfoFuture = ref.read(versionInfoProvider.future);
    final box = context.findRenderObject() as RenderBox?;
    final pos = box!.localToGlobal(Offset.zero) & box.size;

    var appV = await versionInfoFuture;
    var machines = await machineRepository.fetchAll();
    var layouts = await dashboardLayoutService.availableLayouts();

    var exportSnapshot = AppDataExport(
      version: appV.version,
      exportDate: DateTime.now(),
      machines: machines,
      layouts: layouts,
    );

    var export = jsonEncode(exportSnapshot);
    talker.info('Export data: $export');

    debugPrint(export);

    final tmpDir = await getTemporaryDirectory();
    final File file = File('${tmpDir.path}/mobileraker_machines_export_${DateTime.now().toIso8601String()}.json');
    await file.writeAsString(export);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        sharePositionOrigin: pos,
        subject: 'Mobileraker Machines Export',
      ),
    );
  }

  void onImportTap(WidgetRef ref, BuildContext context) async {
    var snackbarService = ref.read(snackBarServiceProvider);
    var machineService = ref.read(machineServiceProvider);
    var dashboardRepo = ref.read(dashboardLayoutHiveRepositoryProvider);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withReadStream: true,
      withData: false,
    );

    if (result == null) return;
    var file = result.files.first;
    var content = await utf8.decodeStream(file.readStream!);
    var json = jsonDecode(content);
    var appDataExport = AppDataExport.fromJson(json);

    talker.info(
      'Importing App Data Export from ${appDataExport.exportDate} with ${appDataExport.machines.length} machines and ${appDataExport.layouts.length} layouts.',
    );
    // Restore Machines
    for (var machine in appDataExport.machines) {
      // just assign new uuid to avoid conflicts
      machine = machine.copyWith(uuid: Uuid().v4());

      talker.info('Importing machine: ${machine.name} with new UUID: ${machine.uuid}');
      // For now we will just add all machines, in the future we offer UI to select which machines to import
      await machineService.addMachine(machine);
    }
    talker.info('Imported ${appDataExport.machines.length} machines.');

    // Restore Layouts
    for (var layout in appDataExport.layouts) {
      // just assign new uuid to avoid conflicts
      layout = layout.copyWith(uuid: Uuid().v4(), name: '${layout.name} (imported)');

      talker.info('Importing layout: ${layout.name} with new UUID: ${layout.uuid}: ${layout.created}');
      // For now we will just add all layouts, in the future we offer UI to select which layouts to import
      await dashboardRepo.create(layout);
    }

    talker.info('Imported ${appDataExport.layouts.length} layouts.');

    snackbarService.show(
      SnackBarConfig(
        title: 'pages.setting.data.snack_imported.title'.tr(),
        message: 'pages.setting.data.snack_imported.message'.tr(args: [appDataExport.machines.length.toString(), appDataExport.layouts.length.toString()]),
      ),
    );
  }
}
