/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_extruder.dart';
import 'package:common/data/dto/config/config_heater_bed.dart';
import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/decorator_suffix_icon_button.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/TextSelectionToolbar.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';
import 'package:mobileraker/ui/screens/printers/components/http_headers.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:mobileraker/ui/screens/printers/components/ssid_preferences_list.dart';
import 'package:mobileraker/ui/screens/printers/components/ssl_settings.dart';
import 'package:mobileraker/ui/screens/printers/edit/components/misc_ordering_list.dart';
import 'package:mobileraker/ui/screens/printers/edit/components/sensor_ordering_list.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stringr/stringr.dart';

import 'components/fans_ordering_list.dart';
import 'components/macro_group_list.dart';
import 'printers_edit_controller.dart';

class PrinterEditPage extends ConsumerWidget {
  const PrinterEditPage({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        currentlyEditingProvider.overrideWithValue(machine),
        printerEditControllerProvider,
        machineRemoteSettingsProvider,
        webcamListControllerProvider,
        temperaturePresetListControllerProvider,
        moveStepStateProvider,
        babyStepStateProvider,
        extruderStepStateProvider,
      ],
      child: const _PrinterEdit(),
    );
  }
}

class _PrinterEdit extends ConsumerWidget {
  const _PrinterEdit();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var canShowImport = ref.watch(allMachinesProvider.select((value) => (value.valueOrNull?.length ?? 0) > 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'pages.printer_edit.title',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).tr(args: [ref.watch(currentlyEditingProvider).name]),
        actions: [
          if (canShowImport)
            IconButton(
              icon: const Icon(FlutterIcons.import_mco),
              tooltip: 'pages.printer_edit.import_settings'.tr(),
              onPressed: ref.watch(printerEditControllerProvider.notifier).openImportSettings,
              // onPressed: () =>                    model.onImportSettings(MaterialLocalizations.of(context))
            ),
        ],
      ),
      floatingActionButton: ref.watch(printerEditControllerProvider)
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(),
            )
          : FloatingActionButton(
              onPressed: ref.read(printerEditControllerProvider.notifier).saveForm,
              child: const Icon(Icons.save_outlined),
            ),
      body: const _Body(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(currentlyEditingProvider);

    var isSaving = ref.watch(printerEditControllerProvider);
    var controller = ref.watch(printerEditControllerProvider.notifier);

    return Center(
      child: ResponsiveLimit(
        child: SingleChildScrollView(
          child: FormBuilder(
            enabled: !isSaving,
            key: ref.watch(editPrinterFormKeyProvider),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                children: <Widget>[
                  SectionHeader(
                    title: 'pages.setting.general.title'.tr(),
                    padding: EdgeInsets.zero,
                  ),
                  FormBuilderTextField(
                    enableInteractiveSelection: true,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'pages.printer_edit.general.displayname'.tr(),
                    ),
                    name: 'printerName',
                    initialValue: machine.name,
                    validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required()],
                    ),
                    contextMenuBuilder: defaultContextMenuBuilder,
                  ),
                  const _ThemeSelector(),
                  FormBuilderTextField(
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'pages.printer_edit.general.printer_addr'.tr(),
                      hintText: 'pages.printer_edit.general.full_url'.tr(),
                    ),
                    name: 'printerUrl',
                    initialValue: machine.httpUri.toString(),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.url(
                        requireTld: false,
                        requireProtocol: false,
                        protocols: ['http', 'https'],
                      ),
                    ]),
                    contextMenuBuilder: defaultContextMenuBuilder,
                  ),
                  FormBuilderTextField(
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'pages.printer_edit.general.moonraker_api_key'.tr(),
                      suffix: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          child: const Icon(Icons.qr_code_sharp, size: 18),
                          onTap: () => controller.openQrScanner(context),
                        ),
                      ),
                      helperText: 'pages.printer_edit.general.moonraker_api_desc'.tr(),
                      helperMaxLines: 5,
                    ),
                    name: 'printerApiKey',
                    initialValue: machine.apiKey,
                    contextMenuBuilder: defaultContextMenuBuilder,
                  ),
                  FormBuilderTextField(
                    keyboardType: const TextInputType.numberWithOptions(),
                    decoration: InputDecoration(
                      labelText: 'pages.printer_edit.general.timeout_label'.tr(),
                      helperText: 'pages.printer_edit.general.timeout_helper'.tr(),
                      helperMaxLines: 5,
                      suffixText: 's',
                    ),
                    name: 'printerLocalTimeout',
                    initialValue: machine.timeout.toString(),
                    contextMenuBuilder: defaultContextMenuBuilder,
                    valueTransformer: (String? text) => text?.let(int.tryParse) ?? 5,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.min(0),
                      FormBuilderValidators.max(600),
                      FormBuilderValidators.integer(),
                    ]),
                  ),
                  SslSettings(
                    initialCertificateDER: machine.pinnedCertificateDERBase64,
                    initialTrustSelfSigned: machine.trustUntrustedCertificate,
                  ),
                  HttpHeaders(initialValue: machine.httpHeaders),
                  const Divider(),
                  // if (machine.hasRemoteConnection)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SsidPreferenceList(initialValue: machine.localSsids),
                  ),
                  WarningCard(
                    show: ref
                            .watch(permissionStatusProvider(Permission.location).selectAs((data) => !data.isGranted))
                            .valueOrNull ==
                        true,
                    title: const Text('pages.printer_edit.wifi_access_warning.title').tr(),
                    subtitle: const Text(
                      'pages.printer_edit.wifi_access_warning.subtitle',
                    ).tr(),
                    leadingIcon: const Icon(Icons.wifi_off_outlined),
                    onTap: controller.requestLocationPermission,
                  ),
                  FullWidthButton(
                    onPressed: controller.openRemoteConnectionSheet,
                    child: const Text(
                      'pages.printer_edit.configure_remote_connection',
                    ).tr(),
                  ),
                  const Divider(),
                  const _RemoteSettings(),
                  const Divider(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TextButton.icon(
                      onPressed: isSaving ? null : controller.deleteIt,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('pages.printer_edit.remove_printer').tr(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WebcamList extends ConsumerWidget {
  const WebcamList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var cams = ref.watch(webcamListControllerProvider);
    return cams.when(
      skipLoadingOnReload: true,
      data: (data) {
        if (data.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: const Text('pages.printer_edit.cams.no_webcams').tr(),
          );
        }

        return ReorderableListView(
          buildDefaultDragHandles: false,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          onReorder: ref.read(webcamListControllerProvider.notifier).onWebCamReorder,
          onReorderStart: (i) => FocusScope.of(context).unfocus(),
          children: List.generate(data.length, (index) {
            WebcamInfo cam = data[index];
            return _WebCamItem(
              key: ValueKey(cam.uuid),
              cam: cam,
              idx: index,
            );
          }),
        );
      },
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('Error while loading webcam: $e'),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.all(8.0),
        child: const Text('general.fetching').tr(),
      ),
    );
  }
}

class _WebCamItem extends HookConsumerWidget {
  final WebcamInfo cam;
  final int idx;

  const _WebCamItem({super.key, required this.cam, required this.idx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var camName = useState(cam.name);
    var serviceType = useState(cam.service);
    var themeData = Theme.of(context);
    return Card(
      child: ExpansionTile(
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 10),
        title: Text(camName.value),
        // TODO Add webcam reorder again?
        // leading: ReorderableDragStartListener(
        //   index: idx,
        //   child: const Icon(Icons.drag_handle),
        // ),
        children: (cam.isReadOnly)
            ? [const Text('pages.printer_edit.cams.read_only').tr()]
            : [
                if (cam.service.forSupporters && !ref.watch(isSupporterProvider))
                  SupporterOnlyFeature(
                    text: const Text(
                      'components.supporter_only_feature.webcam',
                    ).tr(args: [cam.service.name.titleCase()]),
                  ),
                FormBuilderTextField(
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.displayname'.tr(),
                    suffix: DecoratorSuffixIconButton(
                      icon: Icons.delete,
                      onPressed: ref.watch(printerEditControllerProvider)
                          ? null
                          : () => ref.read(webcamListControllerProvider.notifier).removeWebcam(cam),
                    ),
                  ),
                  name: '${cam.uuid}-camName',
                  initialValue: cam.name,
                  onChanged: (name) =>
                      camName.value = ((name?.isNotEmpty ?? false) ? name! : 'pages.printer_edit.cams.new_cam'.tr()),
                  validator: FormBuilderValidators.compose(
                    [FormBuilderValidators.required()],
                  ),
                  contextMenuBuilder: defaultContextMenuBuilder,
                ),
                FormBuilderTextField(
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.cams.stream_url'.tr(),
                    helperText: '${tr('pages.printer_edit.cams.default_url')}: /webcam/?action=stream',
                  ),
                  name: '${cam.uuid}-streamUrl',
                  initialValue: cam.streamUrl.toString(),
                  validator: FormBuilderValidators.compose(
                    [FormBuilderValidators.required()],
                  ),
                  contextMenuBuilder: defaultContextMenuBuilder,
                ),
                FormBuilderTextField(
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.cams.snapshot_url'.tr(),
                    helperText: '${tr('pages.printer_edit.cams.default_url')}: /webcam/?action=snapshot',
                  ),
                  name: '${cam.uuid}-snapshotUrl',
                  initialValue: cam.snapshotUrl.toString(),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                  ]),
                  contextMenuBuilder: defaultContextMenuBuilder,
                ),
                FormBuilderDropdown(
                  name: '${cam.uuid}-service',
                  initialValue: cam.service,
                  items: {
                    ...WebcamServiceType.renderedValues(),
                    cam.service,
                  }
                      .map((serviceType) => DropdownMenuItem<WebcamServiceType>(
                            enabled: serviceType.supported,
                            value: serviceType,
                            child: Text(
                              '${beautifyName(serviceType.name)} ${serviceType.supported ? '' : '(${tr('general.unsupported')})'}',
                            ),
                          ))
                      .toList(),
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.cams.cam_mode'.tr(),
                  ),
                  onChanged: (WebcamServiceType? v) => serviceType.value = v!,
                ),
                if (serviceType.value == WebcamServiceType.mjpegStreamerAdaptive)
                  FormBuilderTextField(
                    decoration: InputDecoration(
                      labelText: 'pages.printer_edit.cams.target_fps'.tr(),
                      suffix: const Text('FPS'),
                    ),
                    name: '${cam.uuid}-tFps',
                    initialValue: cam.targetFps.toString(),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.min(0),
                      FormBuilderValidators.numeric(),
                      FormBuilderValidators.required(),
                    ]),
                    valueTransformer: (String? text) {
                      return text == null ? 0 : int.tryParse(text);
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: false,
                    ),
                  ),
                FormBuilderDropdown(
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.cams.cam_rotate'.tr(),
                  ),
                  name: '${cam.uuid}-rotate',
                  initialValue: cam.rotation,
                  items: [0, 90, 180, 270]
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text('$e°'),
                          ))
                      .toList(growable: false),
                ),
                FormBuilderSwitch(
                  title: const Text('pages.printer_edit.cams.flip_vertical').tr(),
                  decoration: const InputDecoration(border: InputBorder.none),
                  secondary: const Icon(FlutterIcons.swap_vertical_mco),
                  initialValue: cam.flipVertical,
                  name: '${cam.uuid}-camFV',
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderSwitch(
                  title: const Text('pages.printer_edit.cams.flip_horizontal').tr(),
                  decoration: const InputDecoration(border: InputBorder.none),
                  secondary: const Icon(FlutterIcons.swap_horizontal_mco),
                  initialValue: cam.flipHorizontal,
                  name: '${cam.uuid}-camFH',
                  activeColor: themeData.colorScheme.primary,
                ),
                FullWidthButton(
                  onPressed: serviceType.value.supported
                      ? () => (ref.read(webcamListControllerProvider.notifier).previewWebcam(cam))
                      : null,
                  child: Text(
                      'general.preview'.tr() + (serviceType.value.supported ? '' : ' (${tr('general.unsupported')})')),
                ),
              ],
      ),
    );
  }
}

class _RemoteSettings extends ConsumerWidget {
  const _RemoteSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var isSaving = ref.watch(printerEditControllerProvider);
    var machineUUID = ref.watch(currentlyEditingProvider.select((value) => value.uuid));

    return Column(
      children: ref.watch(machineRemoteSettingsProvider).when(
            data: (machineSettings) {
              return [
                SectionHeader(
                  title: 'pages.dashboard.general.cam_card.webcam'.tr(),
                  trailing: TextButton.icon(
                    onPressed: isSaving ? null : ref.read(webcamListControllerProvider.notifier).addNewWebCam,
                    label: const Text('general.add').tr(),
                    icon: const Icon(FlutterIcons.webcam_mco),
                  ),
                ),
                const WebcamList(),
                const Divider(),
                SectionHeader(title: 'pages.printer_edit.motion_system.title'.tr()),
                FormBuilderSwitch(
                  name: 'invertX',
                  initialValue: machineSettings.inverts[0],
                  title: const Text('pages.printer_edit.motion_system.invert_x').tr(),
                  decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'invertY',
                  initialValue: machineSettings.inverts[1],
                  title: const Text('pages.printer_edit.motion_system.invert_y').tr(),
                  decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'invertZ',
                  initialValue: machineSettings.inverts[2],
                  title: const Text('pages.printer_edit.motion_system.invert_z').tr(),
                  decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderTextField(
                  name: 'speedXY',
                  initialValue: machineSettings.speedXY.toString(),
                  valueTransformer: (text) => (text != null) ? int.tryParse(text) : 0,
                  decoration: InputDecoration(
                      labelText: 'pages.printer_edit.motion_system.speed_xy'.tr(), suffixText: 'mm/s', isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  validator:
                      FormBuilderValidators.compose([FormBuilderValidators.required(), FormBuilderValidators.min(1)]),
                ),
                FormBuilderTextField(
                  name: 'speedZ',
                  initialValue: machineSettings.speedZ.toString(),
                  valueTransformer: (text) => (text != null) ? int.tryParse(text) : 0,
                  decoration: InputDecoration(
                      labelText: 'pages.printer_edit.motion_system.speed_z'.tr(), suffixText: 'mm/s', isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  validator:
                      FormBuilderValidators.compose([FormBuilderValidators.required(), FormBuilderValidators.min(1)]),
                ),
                const MoveStepSegmentInput(),
                const BabyStepSegmentInput(),
                const Divider(),
                SectionHeader(title: 'pages.printer_edit.extruders.title'.tr()),
                FormBuilderTextField(
                  name: 'extrudeSpeed',
                  initialValue: machineSettings.extrudeFeedrate.toString(),
                  valueTransformer: (text) => (text != null) ? int.tryParse(text) : 0,
                  decoration: InputDecoration(
                      labelText: 'pages.printer_edit.extruders.feedrate'.tr(), suffixText: 'mm/s', isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.min(1),
                    FormBuilderValidators.numeric(),
                  ]),
                ),
                const ExtruderStepSegmentInput(),
                FormBuilderTextField(
                  name: 'loadingDistance',
                  initialValue: machineSettings.nozzleExtruderDistance.toString(),
                  valueTransformer: (text) => text?.let(int.tryParse) ?? 100,
                  decoration: InputDecoration(
                    labelText: tr('pages.printer_edit.extruders.filament.loading_distance'),
                    helperText: tr('pages.printer_edit.extruders.filament.loading_distance_helper'),
                    suffixText: 'mm',
                    isDense: true,
                    helperMaxLines: 5,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.min(1),
                    FormBuilderValidators.integer(),
                    FormBuilderValidators.numeric(),
                  ]),
                ),
                FormBuilderTextField(
                  name: 'loadingSpeed',
                  initialValue: machineSettings.loadingSpeed.toString(),
                  valueTransformer: (text) => text?.let(double.tryParse)?.toPrecision(1) ?? 5.0,
                  decoration: InputDecoration(
                    labelText: tr('pages.printer_edit.extruders.filament.loading_speed'),
                    helperText: tr('pages.printer_edit.extruders.filament.loading_speed_helper'),
                    suffixText: 'mm/s',
                    isDense: true,
                    helperMaxLines: 5,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.min(1),
                    FormBuilderValidators.numeric(),
                  ]),
                ),
                FormBuilderTextField(
                  name: 'purgeLength',
                  initialValue: machineSettings.purgeLength.toString(),
                  valueTransformer: (text) => text?.let(int.tryParse) ?? 5,
                  decoration: InputDecoration(
                    labelText: tr('pages.printer_edit.extruders.filament.purge_amount'),
                    helperText: tr('pages.printer_edit.extruders.filament.purge_amount_helper'),
                    suffixText: 'mm',
                    isDense: true,
                    helperMaxLines: 5,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.min(1),
                    FormBuilderValidators.numeric(),
                    FormBuilderValidators.integer(),
                  ]),
                ),
                FormBuilderTextField(
                  name: 'purgeSpeed',
                  initialValue: machineSettings.purgeSpeed.toString(),
                  valueTransformer: (text) => text?.let(double.tryParse)?.toPrecision(1) ?? 2.5,
                  decoration: InputDecoration(
                    labelText: tr('pages.printer_edit.extruders.filament.purge_speed'),
                    helperText: tr('pages.printer_edit.extruders.filament.purge_speed_helper'),
                    suffixText: 'mm/s',
                    isDense: true,
                    helperMaxLines: 5,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.min(1),
                    FormBuilderValidators.numeric(),
                  ]),
                ),
                const Divider(),
                MacroGroupList(machineUUID: machineUUID, enabled: !isSaving),
                const Divider(),
                SectionHeader(
                  title: 'pages.dashboard.general.temp_card.temp_presets'.tr(),
                  trailing: TextButton.icon(
                    onPressed: isSaving
                        ? null
                        : ref.watch(temperaturePresetListControllerProvider.notifier).addNewTemperaturePreset,
                    label: const Text('general.add').tr(),
                    icon: const Icon(FlutterIcons.thermometer_lines_mco),
                  ),
                ),
                const TemperaturePresetList(),
                const Divider(),
                SensorOrderingList(machineUuid: machineUUID),
                const Divider(),
                FansOrderingList(machineUuid: machineUUID),
                const Divider(),
                MiscOrderingList(machineUuid: machineUUID),
                const Divider(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton.icon(
                    onPressed: isSaving ? null : ref.read(printerEditControllerProvider.notifier).resetFcmCache,
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: const Text(
                      'pages.printer_edit.reset_notification_registry',
                      textAlign: TextAlign.center,
                    ).tr(),
                  ),
                ),
              ];
            },
            error: (e, s) => [
              WarningCard(
                title: const Text(
                  'pages.printer_edit.could_not_fetch_additional',
                ).tr(),
                subtitle: const Text('pages.printer_edit.fetch_error_hint').tr(),
                leadingIcon: const Icon(Icons.error_outline),
              ),
            ],
            loading: () => [
              FadingText(
                'pages.printer_edit.fetching_additional_settings'.tr(),
              ),
            ],
          ),
    );
  }
}

class MoveStepSegmentInput extends ConsumerWidget {
  const MoveStepSegmentInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var numberFormat = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());
    var isSaving = ref.watch(printerEditControllerProvider);
    return Segments(
      decoration: InputDecoration(
        labelText: 'pages.printer_edit.motion_system.steps_move'.tr(),
        suffixText: 'mm',
      ),
      options: ref
          .watch(moveStepStateProvider)
          .map((e) => FormBuilderFieldOption(
                value: e,
                child: Text(numberFormat.format(e)),
              ))
          .toList(growable: false),
      onAdd: isSaving ? null : ref.read(moveStepStateProvider.notifier).onAdd,
      onSelected: isSaving ? null : ref.read(moveStepStateProvider.notifier).onSelected,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        FormBuilderValidators.numeric(),
        FormBuilderValidators.min(0.001),
        ref.read(moveStepStateProvider.notifier).validate,
      ]),
      inputType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}

class BabyStepSegmentInput extends ConsumerWidget {
  const BabyStepSegmentInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isSaving = ref.watch(printerEditControllerProvider);
    return Segments(
      decoration: InputDecoration(
        labelText: 'pages.printer_edit.motion_system.steps_baby'.tr(),
        suffixText: 'mm',
      ),
      options: ref
          .watch(babyStepStateProvider)
          .map((e) => FormBuilderFieldOption(value: e, child: Text('$e')))
          .toList(growable: false),
      onAdd: isSaving ? null : ref.read(babyStepStateProvider.notifier).onAdd,
      onSelected: isSaving ? null : ref.read(babyStepStateProvider.notifier).onSelected,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        FormBuilderValidators.numeric(),
        FormBuilderValidators.min(0.001),
        ref.read(babyStepStateProvider.notifier).validate,
      ]),
      inputType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}

class ExtruderStepSegmentInput extends ConsumerWidget {
  const ExtruderStepSegmentInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isSaving = ref.watch(printerEditControllerProvider);
    return Segments(
      decoration: InputDecoration(
        labelText: 'pages.printer_edit.extruders.steps_extrude'.tr(),
        suffixText: 'mm',
      ),
      options: ref
          .watch(extruderStepStateProvider)
          .map((e) => FormBuilderFieldOption(value: e, child: Text('$e')))
          .toList(growable: false),
      onAdd: isSaving ? null : ref.read(extruderStepStateProvider.notifier).onAdd,
      onSelected: isSaving ? null : ref.read(extruderStepStateProvider.notifier).onSelected,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        FormBuilderValidators.numeric(),
        FormBuilderValidators.integer(),
        FormBuilderValidators.min(1),
        ref.read(extruderStepStateProvider.notifier).validate,
      ]),
      inputType: TextInputType.number,
    );
  }
}

class TemperaturePresetList extends ConsumerWidget {
  const TemperaturePresetList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<TemperaturePreset> tempPresets = ref.watch(temperaturePresetListControllerProvider);

    if (tempPresets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: const Text('pages.printer_edit.presets.no_presets').tr(),
      );
    }
    var machine = ref.watch(currentlyEditingProvider);
    return ReorderableListView(
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      onReorder: ref.watch(temperaturePresetListControllerProvider.notifier).onGroupReorder,
      onReorderStart: (i) => FocusScope.of(context).unfocus(),
      children: List.generate(tempPresets.length, (index) {
        TemperaturePreset preset = tempPresets[index];
        return _TempPresetItem(
          key: ValueKey(preset.uuid),
          preset: preset,
          idx: index,
          machine: machine,
        );
      }),
    );
  }
}

class _TempPresetItem extends HookConsumerWidget {
  const _TempPresetItem({
    super.key,
    required this.preset,
    required this.idx,
    required this.machine,
  });

  final TemperaturePreset preset;
  final int idx;
  final Machine machine; // We cant use the provider here since the reordable cant use the provider while dragging!

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var name = useState(preset.name);
    ConfigExtruder? primaryExtConfig =
        ref.watch(printerProvider(machine.uuid).selectAs((data) => data.configFile.primaryExtruder)).valueOrNull;
    ConfigHeaterBed? bedConfig =
        ref.watch(printerProvider(machine.uuid).selectAs((data) => data.configFile.configHeaterBed)).valueOrNull;
    var extruderMaxTemp = (primaryExtConfig?.maxTemp ?? 500).toInt();
    var bedMaxTemp = (bedConfig?.maxTemp ?? 120).toInt();
    return Card(
      child: ExpansionTile(
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        title: Text(name.value),
        leading: ReorderableDragStartListener(
          index: idx,
          child: const Icon(Icons.drag_handle),
        ),
        children: [
          FormBuilderTextField(
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'pages.printer_edit.general.displayname'.tr(),
              suffix: DecoratorSuffixIconButton(
                icon: Icons.delete,
                onPressed: ref.watch(printerEditControllerProvider)
                    ? null
                    : () => ref
                        .read(
                          temperaturePresetListControllerProvider.notifier,
                        )
                        .removeTemperaturePreset(preset),
              ),
            ),
            name: '${preset.uuid}-presetName',
            initialValue: name.value,
            onChanged: (v) => name.value = ((v?.isEmpty ?? true) ? 'pages.printer_edit.presets.new_preset'.tr() : v!),
            validator: FormBuilderValidators.compose(
              [FormBuilderValidators.required()],
            ),
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
              labelText: tr('pages.printer_edit.presets.hotend_temp'),
              suffixText: '°C',
            ),
            name: '${preset.uuid}-extruderTemp',
            initialValue: preset.extruderTemp.toString(),
            valueTransformer: (String? text) => (text != null) ? int.tryParse(text) : primaryExtConfig?.minTemp ?? 0,
            validator: FormBuilderValidators.compose(
              [
                FormBuilderValidators.required(),
                FormBuilderValidators.min(0),
                FormBuilderValidators.max(
                  extruderMaxTemp,
                  errorText: 'Heater only allows up to $extruderMaxTemp°C',
                ),
              ],
            ),
            keyboardType: TextInputType.number,
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
              labelText: tr('pages.printer_edit.presets.bed_temp'),
              suffixText: '°C',
            ),
            name: '${preset.uuid}-bedTemp',
            initialValue: preset.bedTemp.toString(),
            valueTransformer: (String? text) => (text != null) ? int.tryParse(text) : bedConfig?.minTemp ?? 0,
            validator: FormBuilderValidators.compose(
              [
                FormBuilderValidators.required(),
                FormBuilderValidators.min(0),
                FormBuilderValidators.max(
                  bedMaxTemp,
                  errorText: 'Heater only allows up to $bedMaxTemp°C',
                ),
              ],
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}

//
// //ToDo: Better name for this widget
class Segments<T> extends StatefulWidget {
  const Segments({
    super.key,
    this.decoration = const InputDecoration(),
    this.maxOptions = 5,
    required this.options,
    this.onSelected,
    this.onAdd,
    this.validator,
    this.inputType,
  });

  final InputDecoration decoration;

  final int maxOptions;

  final List<FormBuilderFieldOption<T>> options;

  final Function(T)? onSelected;

  final Function(String)? onAdd;

  final FormFieldValidator<String>? validator;

  final TextInputType? inputType;

  @override
  State<Segments<T>> createState() => _SegmentsState<T>();
}

class _SegmentsState<T> extends State<Segments<T>> {
  bool editing = false;
  TextEditingController textCtrler = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.validator != null) textCtrler.addListener(validateInput);
  }

  validateInput() {
    String text = textCtrler.text;

    if (T == double) {
      text = text.replaceAll(',', '.');
    }

    setState(() {
      error = widget.validator!(text);
    });
  }

  submit() {
    setState(() {
      String curText = textCtrler.text;
      if (curText.isNotEmpty) widget.onAdd!(curText);
      editing = false;
    });
  }

  Future<bool> cancel() {
    if (editing == false) return Future.value(true);

    setState(() {
      editing = false;
    });
    return Future.value(false);
  }

  onChipPressed(FormBuilderFieldOption<T> option) {
    if (widget.onSelected != null) widget.onSelected!(option.value);
  }

  goIntoEditing() {
    setState(() {
      textCtrler.clear();
      editing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: kThemeAnimationDuration,
      crossFadeState: editing ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: buildEditing(context),
      secondChild: buildNonEditing(context),
    );
  }

  Widget buildEditing(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        var pop = await cancel();
        var naviator = Navigator.of(context);
        if (pop && naviator.canPop()) {
          naviator.pop();
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: textCtrler,
              onEditingComplete: submit,
              decoration: widget.decoration.copyWith(errorText: error),
              keyboardType: widget.inputType,
            ),
          ),
          IconButton(
            color: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.done),
            onPressed: error == null ? submit : null,
          ),
        ],
      ),
    );
  }

  InputDecorator buildNonEditing(BuildContext context) {
    return InputDecorator(
      decoration: widget.decoration,
      child: Wrap(
        direction: Axis.horizontal,
        verticalDirection: VerticalDirection.down,
        children: <Widget>[
          for (FormBuilderFieldOption<T> option in widget.options)
            ChoiceChip(
              selected: false,
              label: option,
              onSelected: widget.onSelected == null ? null : (s) => onChipPressed(option),
            ),
          if (widget.options.isEmpty)
            ChoiceChip(
              label: const Text('pages.printer_edit.no_values_found').tr(),
              selected: false,
              onSelected: (v) {},
            ),
          if (widget.onAdd != null && widget.options.length < widget.maxOptions)
            ChoiceChip(
              backgroundColor: Theme.of(context).colorScheme.primary,
              label: Text(
                '+',
                style: DefaultTextStyle.of(context).style.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
              selected: false,
              onSelected: (v) => goIntoEditing(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    textCtrler.dispose();
    super.dispose();
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeService = ref.watch(themeServiceProvider);
    var machine = ref.watch(currentlyEditingProvider);
    List<ThemePack> themeList = themeService.themePacks;
    var themeData = Theme.of(context);
    var isSupporter = ref.watch(isSupporterProvider);
    return FormBuilderDropdown<int>(
      initialValue: machine.printerThemePack,
      name: 'printerThemePack',
      items: [
        const DropdownMenuItem(value: -1, child: Text('App Theme')),
        ...themeList.mapIndex((theme, idx) {
          var brandingIcon = (themeData.brightness == Brightness.light) ? theme.brandingIcon : theme.brandingIconDark;
          return DropdownMenuItem(
            value: idx,
            child: Row(
              children: [
                (brandingIcon == null)
                    ? SvgPicture.asset(
                        'assets/vector/mr_logo.svg',
                        width: 32,
                        height: 32,
                      )
                    : Image(height: 32, width: 32, image: brandingIcon),
                const SizedBox(width: 8),
                Flexible(child: Text(theme.name)),
              ],
            ),
          );
        }),
      ],
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: tr('pages.printer_edit.general.theme'),
        helperText: isSupporter ? tr('pages.printer_edit.general.theme_helper') : null,
        suffix: isSupporter
            ? null
            : IconButton(
                constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                icon: const Icon(FlutterIcons.hand_holding_heart_faw5s),
                onPressed:
                    isSupporter ? null : ref.read(printerEditControllerProvider.notifier).printerThemeSupporterDialog,
              ),
      ),
      enabled: isSupporter,
      onChanged: (int? index) {
        if (index == null || index < 0 || index >= themeList.length) {
          themeService.selectSystemThemePack();
        } else {
          themeService.selectThemePack(themeList[index], false);
        }
      },
      // themeService.selectThemePack(themeData!),
    );
  }
}
