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
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
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
import 'package:mobileraker_pro/spoolman/dto/create_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/update_filament.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/bottomsheet/selection_bottom_sheet.dart';
import '../printers/components/section_header.dart';

part 'filament_form_page.freezed.dart';
part 'filament_form_page.g.dart';

enum _FormMode { create, update, copy }

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

@Riverpod(dependencies: [])
GetVendor? _initialVendor(Ref _) => throw UnimplementedError();

@Riverpod(dependencies: [])
GetFilament? _initialFilament(Ref _) => throw UnimplementedError();

@Riverpod(dependencies: [])
_FormMode _formMode(Ref _) => _FormMode.create;

class FilamentFormPage extends StatelessWidget {
  const FilamentFormPage({
    super.key,
    required this.machineUUID,
    this.initialFilament,
    this.initialVendor,
    this.isCopy = false,
  });

  final String machineUUID;
  final GetFilament? initialFilament;
  final GetVendor? initialVendor;
  final bool isCopy;

  @override
  Widget build(BuildContext context) {
    var mode = isCopy ? _FormMode.copy : (initialFilament == null ? _FormMode.create : _FormMode.update);

    return ProviderScope(
      // Make sure we are able to access the vendor in all places
      overrides: [
        _initialFilamentProvider.overrideWithValue(initialFilament),
        _formModeProvider.overrideWithValue(mode),
        _initialVendorProvider.overrideWithValue(initialVendor),
      ],
      child: _FilamentFormPage(machineUUID: machineUUID),
    );
  }
}

final _formKey = GlobalKey<FormBuilderState>();

class _FilamentFormPage extends HookConsumerWidget {
  const _FilamentFormPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_FilamentFormPageControllerProvider(machineUUID).notifier);
    final (selectedVendor, sourceFilament) =
        ref.watch(_FilamentFormPageControllerProvider(machineUUID).select((d) => (d.selectedVendor, d.source)));

    final numFormatInputs = NumberFormat('0.##', context.locale.toStringWithSeparator());

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
                  initialValue: sourceFilament?.name,
                  focusNode: nameFocusNode,
                  keyboardType: TextInputType.text,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.name'.tr()),
                  onSubmitted: (txt) => focusNext(_FilamentFormFormComponent.name.name, nameFocusNode, vendorFocusNode),
                  textInputAction: TextInputAction.next,
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.vendor.name,
                  initialValue: selectedVendor?.name,
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
                  initialValue: sourceFilament?.material,
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
                  initialValue: sourceFilament?.colorHex?.let((e) => e.toColor),
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
                    },
                  ),
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.price.name,
                  initialValue: sourceFilament?.price?.let(numFormatInputs.format),
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
                  initialValue: sourceFilament?.diameter.let(numFormatInputs.format) ?? '1.75',
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
                  initialValue: sourceFilament?.density.let(numFormatInputs.format),
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
                  initialValue: sourceFilament?.weight?.let(numFormatInputs.format),
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
                  initialValue: sourceFilament?.spoolWeight?.let(numFormatInputs.format),
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
                SectionHeader(title: tr('pages.spoolman.property_sections.print_settings')),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.extruderTemp.name,
                  initialValue: sourceFilament?.settingsExtruderTemp?.let(numFormatInputs.format),
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
                  initialValue: sourceFilament?.settingsBedTemp?.let(numFormatInputs.format),
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
                  initialValue: sourceFilament?.articleNumber,
                  focusNode: articleNumberFocusNode,
                  keyboardType: TextInputType.text,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: 'pages.spoolman.properties.article_number'.tr()),
                  onSubmitted: (txt) => focusNext(
                      _FilamentFormFormComponent.articleNumber.name, articleNumberFocusNode, commentFocusNode),
                  textInputAction: TextInputAction.next,
                ),
                FormBuilderTextField(
                  name: _FilamentFormFormComponent.comment.name,
                  initialValue: sourceFilament?.comment,
                  maxLines: null,
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

class _AppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _AppBar({required this.machineUUID});

  final String machineUUID;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCreate =
        ref.watch(_filamentFormPageControllerProvider(machineUUID).select((d) => d.mode != _FormMode.update));
    final title = isCreate
        ? tr('pages.spoolman.filament_form.create_page_title')
        : tr('pages.spoolman.filament_form.update_page_title');

    return AppBar(title: Text(title));
  }
}

@Riverpod(dependencies: [_initialFilament, _formMode, _initialVendor])
class _FilamentFormPageController extends _$FilamentFormPageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  _Model build(String machineUUID) {
    ref.keepAliveExternally(spoolmanServiceProvider(machineUUID));
    final vendors = ref.watch(vendorListProvider(machineUUID).selectAs((d) => d.items));

    ref.listenSelf((prev, next) {
      logger.i('[FilamentFormPageController($machineUUID)] State changed: $next');
    });

    final initialVendor = ref.watch(_initialVendorProvider);
    final source = ref.watch(_initialFilamentProvider);
    final mode = ref.watch(_formModeProvider);

    return _Model(
      mode: mode,
      source: source,
      vendors: vendors,
      selectedVendor: stateOrNull?.selectedVendor ?? source?.vendor ?? initialVendor,
    );
  }

  void onFormSubmitted(Map<String, dynamic>? formData) {
    logger.i('[FilamentFormPageController($machineUUID)] onFormSubmitted');
    if (formData == null || state.selectedVendor == null) {
      logger.w('[FilamentFormPageController($machineUUID)] onFormSubmitted: formData or selectedVendor is null');
      return;
    }

    state = state.copyWith(isSaving: true);

    switch (state.mode) {
      case _FormMode.create:
      case _FormMode.copy:
        _create(formData, state.selectedVendor!);
        break;
      case _FormMode.update:
        _update(formData, state.selectedVendor!);
        break;
    }
  }

  void onTapVendorSelection() async {
    if (state.vendors.valueOrNull == null) return;
    final vendors = state.vendors.requireValue;

    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        isScrollControlled: true,
        data: SelectionBottomSheetArgs<GetVendor>(
          options: [
            for (final vendor in vendors.sortedBy((e) => e.name))
              SelectionOption(value: vendor, selected: state.selectedVendor?.id == vendor.id, label: vendor.name),
          ],
          title: const Text('pages.spoolman.vendor.one').tr(),
        ),
      ),
    );

    if (!res.confirmed || res.data is! GetVendor) return;
    state = state.copyWith(selectedVendor: res.data as GetVendor);
  }

  Future<void> _create(Map<String, dynamic> formData, GetVendor vendor) async {
    final dto = _createDtoFromForm(formData, vendor);
    logger.i('[FilamentFormPageController($machineUUID)] Create DTO: $dto');
    final entityName = tr('pages.spoolman.filament.one');
    try {
      final res = await _spoolmanService.createFilament(dto);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.create.success.title', args: [entityName]),
        message: tr('pages.spoolman.create.success.message.one', args: [entityName]),
      ));
      _goRouter.pop(res);
    } catch (e, s) {
      logger.e('[FilamentFormPageController($machineUUID)] Error while saving.', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.create.error.title', args: [entityName]),
        message: tr('pages.spoolman.create.error.message'),
      ));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> _update(Map<String, dynamic> formData, GetVendor vendor) async {
    final dto = _updateDtoFromForm(formData, vendor, state.source!);
    logger.i('[FilamentFormPageController($machineUUID)] Update DTO: $dto');
    final entityName = tr('pages.spoolman.filament.one');

    if (dto == null) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('pages.spoolman.update.no_changes.title'),
        message: tr('pages.spoolman.update.no_changes.message', args: [entityName]),
      ));
      _goRouter.pop();
      return;
    }

    try {
      final updated = await _spoolmanService.updateFilament(dto);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.update.success.title', args: [entityName]),
        message: tr('pages.spoolman.update.success.message', args: [entityName]),
      ));
      _goRouter.pop(updated);
    } catch (e, s) {
      logger.e('[FilamentFormPageController($machineUUID)] Error while saving.', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.update.error.title', args: [entityName]),
        message: tr('pages.spoolman.update.error.message'),
      ));
      _goRouter.pop();
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  CreateFilament _createDtoFromForm(Map<String, dynamic> formData, GetVendor vendor) {
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

  UpdateFilament? _updateDtoFromForm(Map<String, dynamic> formData, GetVendor vendor, GetFilament source) {
    final name = formData[_FilamentFormFormComponent.name.name];
    final material = formData[_FilamentFormFormComponent.material.name];
    final price = formData[_FilamentFormFormComponent.price.name];
    final density = formData[_FilamentFormFormComponent.density.name];
    final diameter = formData[_FilamentFormFormComponent.diameter.name];
    final weight = formData[_FilamentFormFormComponent.weight.name];
    final spoolWeight = formData[_FilamentFormFormComponent.spoolWeight.name];
    final articleNumber = formData[_FilamentFormFormComponent.articleNumber.name];
    final comment = formData[_FilamentFormFormComponent.comment.name];
    final extruderTemp = formData[_FilamentFormFormComponent.extruderTemp.name];
    final bedTemp = formData[_FilamentFormFormComponent.bedTemp.name];
    final colorHex = (formData[_FilamentFormFormComponent.colorHex.name] as Color?)?.hexCode;

    // If no changes were made, return null
    if (vendor.id == source.vendor?.id &&
        name == source.name &&
        material == source.material &&
        price == source.price &&
        density == source.density &&
        diameter == source.diameter &&
        weight == source.weight &&
        spoolWeight == source.spoolWeight &&
        articleNumber == source.articleNumber &&
        comment == source.comment &&
        extruderTemp == source.settingsExtruderTemp &&
        bedTemp == source.settingsBedTemp &&
        colorHex == source.colorHex) return null;

    return UpdateFilament(
      id: source.id,
      name: source.name == name ? null : name,
      vendor: source.vendor?.id == vendor.id ? null : vendor,
      material: source.material == material ? null : material,
      price: source.price == price ? null : price,
      density: source.density == density ? null : density,
      diameter: source.diameter == diameter ? null : diameter,
      weight: source.weight == weight ? null : weight,
      spoolWeight: source.spoolWeight == spoolWeight ? null : spoolWeight,
      articleNumber: source.articleNumber == articleNumber ? null : articleNumber,
      comment: source.comment == comment ? null : comment,
      settingsExtruderTemp: source.settingsExtruderTemp == extruderTemp ? null : extruderTemp,
      settingsBedTemp: source.settingsBedTemp == bedTemp ? null : bedTemp,
      colorHex: source.colorHex == colorHex ? null : colorHex,
    );
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required _FormMode mode,
    required GetFilament? source,
    required AsyncValue<List<GetVendor>> vendors,
    GetVendor? selectedVendor,
    @Default(false) isSaving,
  }) = __Model;
}
