/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/decorator_suffix_icon_button.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/webcam_preview_dialog.dart';
import 'package:mobileraker/util/validator/custom_form_builder_validators.dart';
import 'package:stringr/stringr.dart';

class WebcamsFormField extends StatelessWidget {
  const WebcamsFormField({
    super.key,
    required this.name,
    required this.initialValue,
    required this.machine,
    this.headerBuilder,
  });

  final String name;
  final Machine machine;
  final List<WebcamInfo> initialValue;
  final Widget Function(BuildContext context, VoidCallback? onAddWebcam)? headerBuilder;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField(
      name: name,
      initialValue: initialValue,
      builder: (FormFieldState<List<WebcamInfo>> field) {
        final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (headerBuilder != null)
              headerBuilder!(
                context,
                (() => field.didChange(List.unmodifiable([...?field.value, WebcamInfo.mjpegDefault()]))).only(enabled),
              ),
            _WebcamList(machine: machine, field: field),
          ],
        );
      },
    );
  }
}

class _WebcamList extends ConsumerWidget {
  const _WebcamList({super.key, required this.machine, required this.field});

  final Machine machine;
  final FormFieldState<List<WebcamInfo>> field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
    final data = field.value ?? [];

    if (data.isEmpty) {
      return Padding(padding: const EdgeInsets.all(8.0), child: const Text('pages.printer_edit.cams.no_webcams').tr());
    }
    final List<String> camNames = List.unmodifiable(data.map((c) => c.name));

    return ReorderableListView(
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      onReorder: onReorder,
      // Unfocus to prevent keyboard from hiding the dragged item
      onReorderStart: (i) => FocusScope.of(context).unfocus(),
      children: List.generate(data.length, (index) {
        WebcamInfo cam = data[index];
        return _WebCamItem(
          key: cam.uid?.let(Key.new) ?? ValueKey('webcam_$index'),
          machine: machine,
          cam: cam,
          idx: index,
          camNames: camNames,
          onChanged: ((updated) => onWebcamDataChanged(index, updated)).only(enabled),
          onRemove: (() => onRemove(cam)).only(enabled),
        );
      }),
    );
  }

  void onWebcamDataChanged(int index, WebcamInfo updated) {
    final data = field.value ?? [];
    final updatedList = [...data]..[index] = updated;
    field.didChange(List.unmodifiable(updatedList));
  }

  void onReorder(int oldIndex, int newIndex) {
    final data = field.value ?? [];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updated = [...data];
    WebcamInfo tmp = updated.removeAt(oldIndex);
    updated.insert(newIndex, tmp);
    field.didChange(List.unmodifiable(updated));
  }

  void onRemove(WebcamInfo webcamInfo) {
    final data = field.value ?? [];
    if (!data.contains(webcamInfo)) return;
    field.didChange(List.unmodifiable([...data]..remove(webcamInfo)));
  }
}

class _WebCamItem extends HookConsumerWidget {
  const _WebCamItem({
    super.key,
    required this.machine,
    required this.cam,
    required this.idx,
    required this.camNames,
    required this.onChanged,
    this.onRemove,
  });

  final Machine machine;
  final WebcamInfo cam;
  final int idx;
  final List<String> camNames;
  final Function(WebcamInfo)? onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = onChanged != null;
    final controller = useExpansibleController();
    return Card(
      child: ExpansionTile(
        controller: controller,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 10),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(cam.name.unless(cam.name.isEmpty) ?? tr('pages.printer_edit.cams.new_cam')),
        leading: ReorderableDragStartListener(
          index: idx,
          enabled: enabled,
          child: Icon(Icons.drag_handle, color: Theme.of(context).disabledColor.unless(enabled)),
        ),
        children: [
          if (cam.isReadOnly)
            const Text('pages.printer_edit.cams.read_only').tr()
          else
            _CamFormBody(
              machine: machine,
              cam: cam,
              camNames: camNames,
              onChanged: onChanged,
              onRemove: onRemove,
              onValidationFailed: (e) {
                if (e != null && !controller.isExpanded) {
                  Future(() => controller.expand());
                }
              },
            ),
        ],
      ),
    );
  }
}

class _CamFormBody extends ConsumerWidget {
  const _CamFormBody({
    super.key,
    required this.machine,
    required this.cam,
    required this.camNames,
    required this.onChanged,
    this.onRemove,
    this.onValidationFailed,
  });

  final Machine machine;
  final WebcamInfo cam;
  final List<String> camNames;
  final Function(WebcamInfo)? onChanged;
  final VoidCallback? onRemove;
  final Function(dynamic)? onValidationFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final enabled = onChanged != null;
    final dialogService = ref.read(dialogServiceProvider);

    // we kinda "abuse" the formbuilder fields here. However, doing it like that we can be sure the validation works. It also covers the parent field!
    // However, we have duplicated state management. But we can live with that for now.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cam.service.forSupporters && !ref.watch(isSupporterProvider))
          SupporterOnlyFeature(
            text: const Text('components.supporter_only_feature.webcam').tr(args: [cam.service.name.titleCase()]),
          ),
        FormBuilderTextField(
          name: '__internal_cam_${cam.uid}_name',
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.general.displayname'.tr(),
            suffix: DecoratorSuffixIconButton(icon: Icons.delete, onPressed: onRemove),
          ),
          onChanged: ((value) => onChanged!(cam.copyWith(name: value ?? ''))).only(enabled),
          initialValue: cam.name,
          validator: MobilerakerFormBuilderValidator.sideEffect(
            FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.unique([...camNames], errorText: tr('pages.printer_edit.cams.cam_name_already_present')),
            ]),
            sideEffect: (e) => onValidationFailed?.call(e),
          ),
        ),
        FormBuilderTextField(
          name: '__internal_cam_${cam.uid}_streamUrl',
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.cams.stream_url'.tr(),
            helperText: '${tr('pages.printer_edit.cams.default_url')}: /webcam/?action=stream',
          ),
          onChanged: ((String? value) => onChanged!(
            cam.copyWith(streamUrl: value?.let(Uri.tryParse) ?? cam.streamUrl),
          )).only(enabled),
          initialValue: cam.streamUrl.toString(),
          validator: MobilerakerFormBuilderValidator.sideEffect(
            FormBuilderValidators.required(),
            sideEffect: (e) => onValidationFailed?.call(e),
          ),
        ),
        FormBuilderTextField(
          name: '__internal_cam_${cam.uid}_snapshotUrl',
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.cams.snapshot_url'.tr(),
            helperText: '${tr('pages.printer_edit.cams.default_url')}: /webcam/?action=snapshot',
          ),
          initialValue: cam.snapshotUrl.toString(),
          onChanged: ((String? value) => onChanged!(
            cam.copyWith(snapshotUrl: value?.let(Uri.tryParse) ?? cam.snapshotUrl),
          )).only(enabled),
          validator: MobilerakerFormBuilderValidator.sideEffect(
            FormBuilderValidators.required(),
            sideEffect: (e) => onValidationFailed?.call(e),
          ),
        ),
        InputDecorator(
          decoration: InputDecoration(labelText: 'pages.printer_edit.cams.cam_mode'.tr()),
          child: DropdownButton<WebcamServiceType>(
            items: [
              for (var serviceType in {...WebcamServiceType.renderedValues(), cam.service})
                DropdownMenuItem<WebcamServiceType>(
                  enabled: serviceType.supported,
                  value: serviceType,
                  child: Text(
                    '${beautifyName(serviceType.name)} ${serviceType.supported ? '' : '(${tr('general.unsupported')})'}',
                  ),
                ),
            ],
            value: cam.service,
            isExpanded: true,
            isDense: true,
            underline: SizedBox.shrink(),
            onChanged: ((value) => onChanged!(cam.copyWith(service: value!))).only(enabled),
          ),
        ),
        if (cam.service == WebcamServiceType.mjpegStreamerAdaptive)
          FormBuilderTextField(
            name: '__internal_cam_${cam.uid}_targetFps',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'pages.printer_edit.cams.target_fps'.tr(),
              suffix: const Text('FPS'),
            ),
            initialValue: cam.targetFps.toString(),
            onChanged: ((String? val) => onChanged!(
              cam.copyWith(targetFps: val?.let(int.tryParse) ?? 0),
            )).only(enabled),
            validator: MobilerakerFormBuilderValidator.sideEffect(
              FormBuilderValidators.compose([
                FormBuilderValidators.min(0),
                FormBuilderValidators.numeric(),
                FormBuilderValidators.required(),
              ]),
              sideEffect: (e) => onValidationFailed?.call(e),
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          ),
        InputDecorator(
          decoration: InputDecoration(labelText: 'pages.printer_edit.cams.cam_rotate'.tr()),
          child: DropdownButton<int>(
            items: [
              for (var angle in [0, 90, 180, 270]) DropdownMenuItem(value: angle, child: Text('$angle°')),
            ],
            value: cam.rotation,
            isExpanded: true,
            isDense: true,
            underline: SizedBox.shrink(),
            onChanged: ((int? value) => onChanged!(cam.copyWith(rotation: value!))).only(enabled),
          ),
        ),
        InputDecorator(
          decoration: const InputDecoration(border: InputBorder.none),
          child: SwitchListTile(
            value: cam.flipVertical,
            title: const Text('pages.printer_edit.cams.flip_vertical').tr(),
            secondary: const Icon(FlutterIcons.swap_vertical_mco),
            activeThumbColor: themeData.colorScheme.primary,
            onChanged: ((value) => onChanged!(cam.copyWith(flipVertical: value))).only(enabled),
            dense: true,
            isThreeLine: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        InputDecorator(
          decoration: const InputDecoration(border: InputBorder.none),
          child: SwitchListTile(
            value: cam.flipHorizontal,
            title: const Text('pages.printer_edit.cams.flip_horizontal').tr(),
            secondary: const Icon(FlutterIcons.swap_horizontal_mco),
            activeThumbColor: themeData.colorScheme.primary,
            onChanged: ((value) => onChanged!(cam.copyWith(flipHorizontal: value))).only(enabled),
            dense: true,
            isThreeLine: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        OutlinedButton(
          onPressed:
              (() => dialogService
                      .show(
                        DialogRequest(
                          type: DialogType.webcamPreview,
                          data: WebcamPreviewDialogArguments(webcamInfo: cam, machine: machine),
                        ),
                      )
                      .ignore())
                  .only(cam.service.supported),
          child: Text('general.preview'.tr() + (cam.service.supported ? '' : ' (${tr('general.unsupported')})')),
        ),
      ],
    );
  }
}
