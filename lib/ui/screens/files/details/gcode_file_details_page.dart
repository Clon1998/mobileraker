/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/gcode_file_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/warning_card.dart';
import 'package:mobileraker_pro/service/moonraker/spoolman_service.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../routing/app_router.dart';

part 'gcode_file_details_page.freezed.dart';
part 'gcode_file_details_page.g.dart';

class GCodeFileDetailPage extends ConsumerWidget {
  const GCodeFileDetailPage({super.key, required this.gcodeFile});

  final GCodeFile gcodeFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [gcodeProvider.overrideWithValue(gcodeFile)],
      child: const _GCodeFileDetailPage(),
    );
  }
}

class _GCodeFileDetailPage extends HookConsumerWidget {
  const _GCodeFileDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler = useAnimationController(duration: const Duration(milliseconds: 400))..forward();

    logger.w('Rebuilding _GCodeFileDetailPage');
    var controller = ref.watch(_gCodeFileDetailsControllerProvider.notifier);
    var model = ref.watch(_gCodeFileDetailsControllerProvider);

    var cacheManager = ref.watch(httpCacheManagerProvider(model.machineUUID));

    var machineUri = ref.watch(previewImageUriProvider);

    var bigImageUri = model.file.constructBigImageUri(machineUri);

    var dateFormatService = ref.watch(dateFormatServiceProvider);
    var dateFormatGeneral = dateFormatService.add_Hm(DateFormat.yMMMd());
    var dateFormatEta = dateFormatService.add_Hm(DateFormat.MMMEd());
    var numFormat = NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);
    var numFormatInt =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 0);
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     file.name,
      //     overflow: TextOverflow.fade,
      //   ),
      // ),
      body: CustomScrollView(
        slivers: [
          SliverLayoutBuilder(builder: (context, constraints) {
            return SliverAppBar(
              expandedHeight: 220,
              floating: true,
              actions: const [_PreHeatBtn()],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Stack(alignment: Alignment.center, children: [
                  Hero(
                    transitionOnUserGestures: true,
                    tag: 'gCodeImage-${model.file.hashCode}',
                    child: IconTheme(
                      data: IconThemeData(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: (bigImageUri != null)
                          ? CachedNetworkImage(
                              cacheManager: cacheManager,
                              imageUrl: bigImageUri.toString(),
                              cacheKey: '${bigImageUri.hashCode}-${model.file.hashCode}',
                              httpHeaders: ref.watch(previewImageHttpHeaderProvider),
                              imageBuilder: (context, imageProvider) => Image(
                                image: imageProvider,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                              placeholder: (context, url) => const Icon(Icons.insert_drive_file),
                              errorWidget: (context, url, error) => const Icon(Icons.file_present),
                            )
                          : const Icon(Icons.insert_drive_file),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizeTransition(
                      sizeFactor: animCtrler.view,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8.0),
                          ),
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                        ),
                        child: Text(
                          model.file.name,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 5,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          }),
          SliverToBoxAdapter(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // if (model.materialMissmatch != null)
              WarningCard(
                show: model.materialMissmatch != null,
                onTap: model.canStartPrint ? controller.changeActiveSpool : null,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                leadingIcon: const Icon(Icons.layers_clear),
                // leadingIcon: Icon(Icons.layers_clear),
                title: const Text('pages.files.details.spoolman_warnings.material_mismatch_title').tr(),
                subtitle: const Text('pages.files.details.spoolman_warnings.material_mismatch_body')
                    .tr(args: [model.file.filamentType ?? '--', model.materialMissmatch ?? '--']),
              ),
              // if (model.insufficientFilament != null)
              WarningCard(
                show: model.insufficientFilament != null,
                onTap: model.canStartPrint ? controller.changeActiveSpool : null,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                leadingIcon: const Icon(Icons.scale),
                title: const Text('pages.files.details.spoolman_warnings.insufficient_filament_title').tr(),
                subtitle: const Text('pages.files.details.spoolman_warnings.insufficient_filament_body')
                    .tr(args: [model.insufficientFilament?.let((it) => it.formatGramms(numFormat)) ?? '--']),
              ),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(
                        FlutterIcons.printer_3d_nozzle_outline_mco,
                      ),
                      title: const Text('pages.setting.general.title').tr(),
                    ),
                    const Divider(),
                    _PropertyTile(
                      title: 'pages.files.details.general_card.path'.tr(),
                      subtitle: model.file.absolutPath,
                    ),
                    _PropertyTile(
                      title: 'pages.files.details.general_card.last_mod'.tr(),
                      subtitle: dateFormatGeneral.format(model.file.modifiedDate),
                    ),
                    _PropertyTile(
                      title: 'pages.files.details.general_card.last_printed'.tr(),
                      subtitle: (model.file.printStartTime != null)
                          ? dateFormatGeneral.format(model.file.lastPrintDate!)
                          : 'pages.files.details.general_card.no_data'.tr(),
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(FlutterIcons.tags_ant),
                      title: const Text('pages.files.details.meta_card.title').tr(),
                    ),
                    const Divider(),
                    _PropertyTile(
                      title: 'pages.files.details.meta_card.filament'.tr(),
                      subtitle: [
                        '${tr('pages.files.details.meta_card.filament_type')}: ${model.file.filamentType ?? tr('general.unknown')}',
                        '${tr('pages.files.details.meta_card.filament_name')}: ${model.file.filamentName ?? tr('general.unknown')}',
                        if (model.file.filamentWeightTotal != null)
                          '${tr('pages.files.details.meta_card.filament_weight')}: ${model.file.filamentWeightTotal!.formatGramms(numFormat)}',
                        if (model.file.filamentTotal != null)
                          '${tr('pages.files.details.meta_card.filament_length')}: ${model.file.filamentTotal!.formatMiliMeters(numFormat)}',
                      ].join('\n'),
                    ),
                    _PropertyTile(
                      title: 'pages.files.details.meta_card.est_print_time'.tr(),
                      subtitle:
                          '${secondsToDurationText(model.file.estimatedTime?.toInt() ?? 0)}, ${tr('pages.dashboard.general.print_card.eta')}: ${formatPotentialEta(model.file, dateFormatEta)}',
                    ),
                    _PropertyTile(
                      title: 'pages.files.details.meta_card.slicer'.tr(),
                      subtitle: formatSlicerAndVersion(model.file),
                    ),
                    _PropertyTile(
                      title: 'pages.files.details.meta_card.nozzle_diameter'.tr(),
                      subtitle: '${model.file.nozzleDiameter} mm',
                    ),
                    _PropertyTile(
                      title: 'pages.files.details.meta_card.layer_higher'.tr(),
                      subtitle:
                          '${tr('pages.files.details.meta_card.first_layer')}: ${model.file.firstLayerHeight?.let(numFormat.format) ?? '?'} mm\n'
                          '${tr('pages.files.details.meta_card.others')}: ${model.file.layerHeight?.let(numFormat.format) ?? '?'} mm',
                    ),
                    _PropertyTile(
                      title: 'pages.files.details.meta_card.first_layer_temps'.tr(),
                      subtitle: 'pages.files.details.meta_card.first_layer_temps_value'.tr(args: [
                        model.file.firstLayerTempExtruder?.toStringAsFixed(0) ?? 'general.unknown'.tr(),
                        model.file.firstLayerTempBed?.toStringAsFixed(0) ?? 'general.unknown'.tr(),
                      ]),
                    ),
                  ],
                ),
              ),
              // Card(
              //   child: Column(
              //     mainAxisSize: MainAxisSize.min,
              //     children: <Widget>[
              //       ListTile(
              //         leading: Icon(FlutterIcons.chart_bar_mco),
              //         title: Text('pages.files.details.stat_card.title').tr(),
              //       ),
              //       Divider(),
              //       Placeholder(
              //
              //       )
              //     ],
              //   ),
              // ),
              const SizedBox(height: 80),
              // Safe Area was not working, added a top padding
            ]),
          ),
        ],
      ),

      floatingActionButton: const _Fab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String formatSlicerAndVersion(GCodeFile file) {
    String ukwn = tr('general.unknown');
    if (file.slicerVersion == null) return file.slicer ?? ukwn;

    return '${file.slicer ?? ukwn} (v${file.slicerVersion})';
  }

  String formatPotentialEta(GCodeFile file, DateFormat dateFormat) {
    if (file.estimatedTime == null) return tr('general.unknown');
    var eta = DateTime.now().add(Duration(seconds: file.estimatedTime!.toInt())).toLocal();
    return dateFormat.format(eta);
  }
}

class _Fab extends ConsumerWidget {
  const _Fab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_gCodeFileDetailsControllerProvider.notifier);
    var canStartPrint = ref.watch(_gCodeFileDetailsControllerProvider.select((data) => data.canStartPrint));

    var themeData = Theme.of(context);
    return FloatingActionButton.extended(
      backgroundColor: (canStartPrint) ? null : themeData.disabledColor,
      onPressed: (canStartPrint) ? controller.onStartPrintTap : null,
      icon: const Icon(FlutterIcons.printer_3d_nozzle_mco),
      label: const Text('pages.files.details.print').tr(),
    );
  }
}

class _PreHeatBtn extends ConsumerWidget {
  const _PreHeatBtn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_gCodeFileDetailsControllerProvider.notifier);
    var canPreheat = ref.watch(_gCodeFileDetailsControllerProvider
        .select((data) => data.canStartPrint && data.file.firstLayerTempBed != null));

    return IconButton(
      onPressed: canPreheat ? controller.onPreHeatPrinterTap : null,
      icon: const Icon(FlutterIcons.fire_alt_faw5s),
      tooltip: 'pages.files.details.preheat'.tr(),
    );
  }
}

class _PropertyTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PropertyTile({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var subtitleTheme = textTheme.bodyMedium?.copyWith(fontSize: 13, color: textTheme.bodySmall?.color);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.left),
          const SizedBox(height: 2),
          Text(subtitle, style: subtitleTheme, textAlign: TextAlign.left),
        ],
      ),
    );
  }
}

@Riverpod(dependencies: [])
GCodeFile gcode(GcodeRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [gcode])
class _GCodeFileDetailsController extends _$GCodeFileDetailsController {
  @override
  _Model build() {
    logger.i('Buildign GCodeFileDetailsController');

    var machineUUID = ref.watch(selectedMachineProvider.select((value) => value.requireValue!.uuid));
    var gCodeFile = ref.watch(gcodeProvider);

    var klippy = ref.watch(klipperProvider(machineUUID)).valueOrNull;
    var canPrint = ref.watch(printerProvider(machineUUID).select((value) => const {
          PrintState.complete,
          PrintState.error,
          PrintState.standby,
          PrintState.cancelled,
        }.contains(value.valueOrNull?.print.state)));

    double? insufficientFilament;
    String? materialMissmatch;
    if (klippy?.hasSpoolmanComponent == true) {
      var spool = ref.watch(activeSpoolProvider(machineUUID)).valueOrNull;
      if (spool != null) {
        if (spool.filament.material != null &&
            gCodeFile.filamentType != null &&
            !equalsIgnoreAsciiCase(gCodeFile.filamentType!.trim(), spool.filament.material!.trim())) {
          materialMissmatch = spool.filament.material?.trim();
        }

        if (gCodeFile.filamentWeightTotal != null &&
            spool.remainingWeight != null &&
            spool.remainingWeight! < gCodeFile.filamentWeightTotal!) {
          insufficientFilament = spool.remainingWeight!;
        }
      }
    }

    return _Model(
      file: gCodeFile,
      canStartPrint: klippy?.klippyCanReceiveCommands == true && canPrint,
      machineUUID: machineUUID,
      insufficientFilament: insufficientFilament,
      materialMissmatch: materialMissmatch,
    );
  }

  PrinterService get _printerService => ref.read(printerServiceSelectedProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  onStartPrintTap() {
    _printerService.startPrintFile(ref.read(gcodeProvider));
    ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
  }

  onPreHeatPrinterTap() {
    var gCodeFile = ref.read(gcodeProvider);
    var tempArgs = [
      '170',
      gCodeFile.firstLayerTempBed?.toStringAsFixed(0) ?? '60',
    ];
    _dialogService
        .showConfirm(
      title: 'pages.files.details.preheat_dialog.title'.tr(),
      body: tr('pages.files.details.preheat_dialog.body', args: tempArgs),
      confirmBtn: 'pages.files.details.preheat'.tr(),
    )
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false) {
        _printerService.setHeaterTemperature('extruder', 170);
        if (ref.read(printerSelectedProvider.selectAs((data) => data.heaterBed != null)).valueOrFullNull ?? false) {
          _printerService.setHeaterTemperature(
            'heater_bed',
            (gCodeFile.firstLayerTempBed ?? 60.0).toInt(),
          );
        }
        _snackBarService.show(SnackBarConfig(
          title: tr('pages.files.details.preheat_snackbar.title'),
          message: tr(
            'pages.files.details.preheat_snackbar.body',
            args: tempArgs,
          ),
        ));
      }
    });
  }

  changeActiveSpool() {
    ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(
          type: ProSheetType.selectSpoolman,
          isScrollControlled: true,
          data: state.machineUUID,
        ));
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required GCodeFile file,
    required bool canStartPrint,
    required String machineUUID,
    required String? materialMissmatch,
    required double? insufficientFilament,
  }) = __Model;
}
