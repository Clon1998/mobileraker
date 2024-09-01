/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/ui/locale_spy.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_extra_fields/form_builder_extra_fields.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/moonraker/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/dto/create_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/filament.dart';
import 'package:mobileraker_pro/spoolman/dto/vendor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/bottomsheet/selection_bottom_sheet.dart';
import '../printers/components/section_header.dart';

part 'filament_form_page.freezed.dart';
part 'filament_form_page.g.dart';

enum _FilamentFormFormComponent {
  name,
  vendor,
  material,
  price,
  density,
  diameter,
  weight,
  spoolWeight,
  articleNumber,
  comment,
  extruderTemp,
  bedTemp,
  colorHex,
}

class FilamentFormPage extends StatelessWidget {
  const FilamentFormPage({super.key, required this.machineUUID, this.filament, this.isCopy = false});

  final String machineUUID;
  final Filament? filament;
  final bool isCopy;

  @override
  Widget build(BuildContext context) {
    return _FilamentFormPage(machineUUID: machineUUID);
  }
}

final _formKey = GlobalKey<FormBuilderState>();

class _FilamentFormPage extends HookConsumerWidget {
  const _FilamentFormPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_FilamentFormPageControllerProvider(machineUUID).notifier);
    final selectedVendor = ref.watch(_FilamentFormPageControllerProvider(machineUUID).select((d) => d.selectedVendor));

    useEffect(
      () {
        _formKey.currentState?.fields[_FilamentFormFormComponent.vendor.name]?.didChange(selectedVendor?.name);
        logger.i('Vendor selection cahnge received from controller: ${selectedVendor?.name}');
      },
      [selectedVendor],
    );

    final nameFocusNode = useFocusNode();
    final vendorFocusNode = useFocusNode();
    final materialFocusNode = useFocusNode();
    final priceFocusNode = useFocusNode();
    final densityFocusNode = useFocusNode();
    final diameterFocusNode = useFocusNode();
    final weightFocusNode = useFocusNode();
    final spoolWeightFocusNode = useFocusNode();
    final articleNumberFocusNode = useFocusNode();
    final commentFocusNode = useFocusNode();
    final extruderTempFocusNode = useFocusNode();
    final bedTempFocusNode = useFocusNode();
    final colorHexFocusNode = useFocusNode();

    return Scaffold(
      appBar: _AppBar(machineUUID: machineUUID),
      floatingActionButton: _Fab(machineUUID: machineUUID),
      body: Center(
        child: SafeArea(
          child: ResponsiveLimit(
            child: FormBuilder(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16.0), children: [
                // Basic Information
                SectionHeader(title: tr('pages.spoolman.property_sections.basic')),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.name.name,
                  focusNode: nameFocusNode,
                  keyboardType: TextInputType.text,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.name'.tr()),
                  onSubmitted: (txt) => focusNext(_FilamentFormFormComponent.name.name, nameFocusNode, vendorFocusNode),
                  textInputAction: TextInputAction.next,
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.vendor.name,
                  focusNode: vendorFocusNode,
                  readOnly: true,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.vendor.one'.tr()),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.vendor.name, vendorFocusNode, materialFocusNode),
                  onTap: controller.onTapVendorSelection,
                  textInputAction: TextInputAction.next,
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.material.name,
                  focusNode: materialFocusNode,
                  keyboardType: TextInputType.text,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.material'.tr()),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.material.name, materialFocusNode, colorHexFocusNode),
                  textInputAction: TextInputAction.next,
                ),
                FormBuilderColorPickerField(
                  name: _FilamentFormFormComponent.colorHex.name,
                  focusNode: colorHexFocusNode,
                  keyboardType: TextInputType.text,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.color'.tr()),
                  onFieldSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.colorHex.name, colorHexFocusNode, priceFocusNode),
                  textInputAction: TextInputAction.next,
                  colorPreviewBuilder: (color) => LayoutBuilder(
                    key: ObjectKey(color),
                    builder: (context, constraints) {
                      return SpoolWidget(
                        color: color?.hexCode,
                        height: constraints.minHeight,
                      );

                      // return Icon(
                      //   Icons.circle,
                      //   key: ObjectKey(state.value),
                      //   size: constraints.minHeight,
                      //   color: state.value,
                      // );
                    },
                  ),
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.price.name,
                  valueTransformer: (text) => text?.let(double.tryParse),
                  focusNode: priceFocusNode,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'pages.spoolman.properties.price'.tr(),
                    suffixText: ref.watch(spoolmanCurrencyProvider(machineUUID)),
                    helperText: tr('pages.spoolman.filament_form.helper.price'),
                    helperMaxLines: 100,
                  ),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.price.name, priceFocusNode, diameterFocusNode),
                  textInputAction: TextInputAction.next,
                  validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                ),
                //Physical Properties
                SectionHeader(title: tr('pages.spoolman.property_sections.physical')),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.diameter.name,
                  valueTransformer: (text) => text?.let(double.tryParse),
                  initialValue: '1.75',
                  focusNode: diameterFocusNode,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.diameter'.tr(), suffixText: '[mm]'),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.diameter.name, diameterFocusNode, densityFocusNode),
                  textInputAction: TextInputAction.next,
                  validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required(), FormBuilderValidators.numeric()]),
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.density.name,
                  valueTransformer: (text) => text?.let(double.tryParse),
                  focusNode: densityFocusNode,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration:
                      InputDecoration(labelText: 'pages.spoolman.properties.density'.tr(), suffixText: '[g/cm³]'),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.density.name, densityFocusNode, weightFocusNode),
                  textInputAction: TextInputAction.next,
                  validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required(), FormBuilderValidators.numeric()]),
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.weight.name,
                  valueTransformer: (text) => text?.let(double.tryParse),
                  focusNode: weightFocusNode,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'pages.spoolman.properties.weight'.tr(),
                    suffixText: '[g]',
                    helperText: tr('pages.spoolman.filament_form.helper.initial_weight'),
                    helperMaxLines: 100,
                  ),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.weight.name, weightFocusNode, spoolWeightFocusNode),
                  textInputAction: TextInputAction.next,
                  validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.spoolWeight.name,
                  valueTransformer: (text) => text?.let(double.tryParse),
                  focusNode: spoolWeightFocusNode,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'pages.spoolman.properties.spool_weight'.tr(),
                    suffixText: '[g]',
                    helperText: tr('pages.spoolman.filament_form.helper.empty_weight'),
                    helperMaxLines: 100,
                  ),
                  onSubmitted: (txt) => focusNext(
                      _FilamentFormFormComponent.spoolWeight.name, spoolWeightFocusNode, extruderTempFocusNode),
                  textInputAction: TextInputAction.next,
                  validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                ),

                // Temperature Settings
                SectionHeader(title: tr('pages.spoolman.property_sections.physical')),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.extruderTemp.name,
                  valueTransformer: (text) => text?.let(int.tryParse),
                  focusNode: extruderTempFocusNode,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration:
                      InputDecoration(labelText: 'pages.printer_edit.presets.hotend_temp'.tr(), suffixText: '[°C]'),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.extruderTemp.name, extruderTempFocusNode, bedTempFocusNode),
                  textInputAction: TextInputAction.next,
                  validator: FormBuilderValidators.compose([FormBuilderValidators.integer()]),
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.bedTemp.name,
                  valueTransformer: (text) => text?.let(int.tryParse),
                  focusNode: bedTempFocusNode,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration:
                      InputDecoration(labelText: 'pages.printer_edit.presets.bed_temp'.tr(), suffixText: '[°C]'),
                  onSubmitted: (txt) =>
                      focusNext(_FilamentFormFormComponent.bedTemp.name, bedTempFocusNode, articleNumberFocusNode),
                  textInputAction: TextInputAction.next,
                  validator: FormBuilderValidators.compose([FormBuilderValidators.integer()]),
                ),

                // Cost and Additional Information
                SectionHeader(title: tr('pages.spoolman.property_sections.additional')),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.articleNumber.name,
                  focusNode: articleNumberFocusNode,
                  keyboardType: TextInputType.text,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.article_number'.tr()),
                  onSubmitted: (txt) => focusNext(
                      _FilamentFormFormComponent.articleNumber.name, articleNumberFocusNode, commentFocusNode),
                  textInputAction: TextInputAction.next,
                ),
                FormBuilderTextField(
                  maxLines: null,
                  name: _FilamentFormFormComponent.comment.name,
                  focusNode: commentFocusNode,
                  keyboardType: TextInputType.multiline,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.comment'.tr()),
                  textInputAction: TextInputAction.newline,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

void focusNext(String componentName, FocusNode currentFocus, FocusNode nextFocus) {
  if (_formKey.currentState?.fields[componentName]?.validate() == true) {
    nextFocus.requestFocus();
  } else {
    currentFocus.requestFocus();
  }
}

class _Fab extends HookConsumerWidget {
  const _Fab({required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_FilamentFormPageControllerProvider(machineUUID).notifier);

    final (isSaving, selectedVendor) = ref.watch(
        _FilamentFormPageControllerProvider(machineUUID).select((model) => (model.isSaving, model.selectedVendor)));

    final themeData = Theme.of(context);

    return FloatingActionButton(
      onPressed: () {
        var formValid = _formKey.currentState?.saveAndValidate();
        if (selectedVendor == null) {
          final fLocale = FormBuilderLocalizations.of(context);

          _formKey.currentState?.fields[_FilamentFormFormComponent.vendor.name]?.invalidate(fLocale.requiredErrorText);
          return;
        }
        if (formValid == true) {
          controller.onFormSubmitted(_formKey.currentState?.value);
        }
      }.unless(isSaving),
      child: isSaving ? CircularProgressIndicator(color: themeData.colorScheme.onPrimary) : const Icon(Icons.save_alt),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.machineUUID});

  final String machineUUID;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text('pages.spoolman.filament_form.create_page_title'.tr()));
  }
}

@riverpod
class _FilamentFormPageController extends _$FilamentFormPageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  _Model build(String machineUUID) {
    final vendors = ref.watch(vendorListProvider(machineUUID).selectAs((d) => d.items));

    return _Model(
      source: null,
      vendors: vendors,
    );
  }

  Future<void> onFormSubmitted(Map<String, dynamic>? formData) async {
    logger.i('[FilamentFormPageController($machineUUID)] onFormSubmitted');
    if (formData == null || state.selectedVendor == null) {
      logger.w('[FilamentFormPageController($machineUUID)] onFormSubmitted: formData or selectedVendor is null');
      return;
    }

    state = state.copyWith(isSaving: true);
    final dto = _dtoFromForm(formData, state.selectedVendor!);
    try {
      //TODO: There is no need to create multiple of the same manufacturer at once!
      await _spoolmanService.createFilament(dto);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.create.success.title', args: [tr('pages.spoolman.filament.one')]),
        message: tr('pages.spoolman.create.success.message.one', args: [tr('pages.spoolman.filament.one')]),
      ));
      _goRouter.pop();
    } catch (e, s) {
      logger.e('[FilamentFormPageController($machineUUID)] error while saving filament', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.create.error.title', args: [tr('pages.spoolman.filament.one')]),
        message: tr('pages.spoolman.create.error.message'),
      ));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  void onTapVendorSelection() async {
    if (state.vendors.valueOrNull == null) return;
    final vendors = state.vendors.requireValue;
    final locale = ref.read(activeLocaleProvider);
    final numberFormat = NumberFormat.decimalPattern(locale.toStringWithSeparator());

    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        isScrollControlled: true,
        data: SelectionBottomSheetArgs<Vendor>(
          options: [
            for (final vendor in vendors.sortedBy((e) => e.name)) SelectionOption(value: vendor, label: vendor.name),
          ],
          title: const Text('pages.spoolman.vendor.one').tr(),
        ),
      ),
    );

    if (!res.confirmed || res.data is! Vendor) return;
    state = state.copyWith(selectedVendor: res.data as Vendor);
  }

  CreateFilament _dtoFromForm(Map<String, dynamic> formData, Vendor vendor) {
    return CreateFilament(
      name: formData[_FilamentFormFormComponent.name.name],
      vendor: vendor,
      material: formData[_FilamentFormFormComponent.material.name],
      price: formData[_FilamentFormFormComponent.price.name],
      density: formData[_FilamentFormFormComponent.density.name],
      diameter: formData[_FilamentFormFormComponent.diameter.name],
      weight: formData[_FilamentFormFormComponent.weight.name],
      spoolWeight: formData[_FilamentFormFormComponent.spoolWeight.name],
      articleNumber: formData[_FilamentFormFormComponent.articleNumber.name],
      settingsExtruderTemp: formData[_FilamentFormFormComponent.extruderTemp.name],
      settingsBedTemp: formData[_FilamentFormFormComponent.bedTemp.name],
      colorHex: (formData[_FilamentFormFormComponent.colorHex.name] as Color?)?.hexCode,
      comment: formData[_FilamentFormFormComponent.comment.name],
    );
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required Filament? source,
    required AsyncValue<List<Vendor>> vendors,
    Vendor? selectedVendor,
    @Default(false) isSaving,
  }) = __Model;
}
