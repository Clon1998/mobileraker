/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-passing-async-when-sync-expected

import 'package:collection/collection.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/ui/locale_spy.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/selection_bottom_sheet.dart';
import 'package:mobileraker_pro/misc/filament_extension.dart';
import 'package:mobileraker_pro/spoolman/dto/create_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/update_spool.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../printers/components/section_header.dart';

part 'spool_form_page.freezed.dart';
part 'spool_form_page.g.dart';

enum _FormMode { create, update, copy }

enum _SpoolFormFormComponent {
  firstUsed,
  lastUsed,
  filament,
  price,
  initialWeight,
  emptyWeight,
  used,
  location,
  lot,
  comment,
}

@Riverpod(dependencies: [])
GetFilament? _initialFilament(_) => throw UnimplementedError();

@Riverpod(dependencies: [])
GetSpool? _initialSpool(_) => throw UnimplementedError();

@Riverpod(dependencies: [])
_FormMode _formMode(Ref ref) => _FormMode.create;

class SpoolFormPage extends StatelessWidget {
  const SpoolFormPage({
    super.key,
    required this.machineUUID,
    this.initialSpool,
    this.initialFilament,
    this.isCopy = false,
  });

  final String machineUUID;
  final GetSpool? initialSpool;
  final GetFilament? initialFilament;
  final bool isCopy;

  @override
  Widget build(BuildContext context) {
    var mode = isCopy ? _FormMode.copy : (initialSpool == null ? _FormMode.create : _FormMode.update);

    return ProviderScope(
      // Make sure we are able to access the vendor in all places
      overrides: [
        _initialSpoolProvider.overrideWithValue(initialSpool),
        _formModeProvider.overrideWithValue(mode),
        _initialFilamentProvider.overrideWithValue(initialFilament),
      ],
      child: _SpoolFormPage(machineUUID: machineUUID),
    );
  }
}

final _formKey = GlobalKey<FormBuilderState>();

class _SpoolFormPage extends HookConsumerWidget {
  const _SpoolFormPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This formatter is using decimal (thousands) separator e.g. 1,000.00
    final numFormatDecimal = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());

    // This formatter is NOT using decimal (thousands) separator e.g. 1000.00
    final numFormatInputs = NumberFormat('0.##', context.locale.toStringWithSeparator());

    final controller = ref.watch(_SpoolFormPageControllerProvider(machineUUID).notifier);
    final (sourceSpool, selectedFilament, mode) = ref.watch(_SpoolFormPageControllerProvider(machineUUID)
        .select((model) => (model.source, model.selectedFilament, model.mode)));

    useEffect(
      () {
        _formKey.currentState?.fields[_SpoolFormFormComponent.filament.name]
            ?.didChange(selectedFilament?.displayNameWithDetails(numFormatDecimal));
        logger.i('Filament selection change received from controller: ${selectedFilament?.name}');
      },
      [selectedFilament],
    );

    final firstUsedFocusNode = useFocusNode();
    final lastUsedFocusNode = useFocusNode();
    final filamentFocusNode = useFocusNode();
    final priceFocusNode = useFocusNode();
    final initialWeightFocusNode = useFocusNode();
    final emptyWeightFocusNode = useFocusNode();
    final usedFocusNode = useFocusNode();
    final locationFocusNode = useFocusNode();
    final lotFocusNode = useFocusNode();
    final commentFocusNode = useFocusNode();

    return Scaffold(
      appBar: _AppBar(machineUUID: machineUUID),
      floatingActionButton: _Fab(machineUUID: machineUUID),
      body: Center(
        child: SafeArea(
          child: ResponsiveLimit(
            child: FormBuilder(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  // Basic Spool Information
                  SectionHeader(title: tr('pages.spoolman.property_sections.basic')),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.filament.name,
                    initialValue: selectedFilament?.displayNameWithDetails(numFormatDecimal),
                    readOnly: true,
                    focusNode: filamentFocusNode,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.filament.one'.tr(),
                      suffixIcon: LayoutBuilder(
                        key: ObjectKey(selectedFilament),
                        builder: (context, constraints) {
                          return SpoolWidget(
                            color: selectedFilament?.colorHex,
                            height: constraints.minHeight,
                          );
                        },
                      ),
                    ),
                    validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
                    onSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.filament.name, filamentFocusNode, priceFocusNode),
                    onTap: controller.onTapFilamentSelection,
                    textInputAction: TextInputAction.next,
                  ),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.price.name,
                    initialValue: sourceSpool?.price?.let(numFormatInputs.format),
                    valueTransformer: (text) => text?.let(double.tryParse),
                    focusNode: priceFocusNode,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.price'.tr(),
                      helperText: 'pages.spoolman.spool_form.helper.price'.tr(),
                      helperMaxLines: 100,
                      hintText: (selectedFilament?.price)?.let(numFormatInputs.format),
                      suffixText: ref.watch(spoolmanCurrencyProvider(machineUUID)),
                    ),
                    onSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.price.name, priceFocusNode, initialWeightFocusNode),
                    textInputAction: TextInputAction.next,
                    validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                  ),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.initialWeight.name,
                    initialValue: sourceSpool?.initialWeight?.let(numFormatInputs.format),
                    valueTransformer: (text) => text?.let(double.tryParse),
                    focusNode: initialWeightFocusNode,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.weight'.tr(),
                      helperText: 'pages.spoolman.spool_form.helper.initial_weight'.tr(),
                      helperMaxLines: 100,
                      hintText: (selectedFilament?.weight)?.let((it) => it.toString()),
                      suffixText: '[g]',
                    ),
                    onSubmitted: (txt) => focusNext(
                        _SpoolFormFormComponent.initialWeight.name, initialWeightFocusNode, emptyWeightFocusNode),
                    textInputAction: TextInputAction.next,
                    validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                  ),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.emptyWeight.name,
                    initialValue: sourceSpool?.spoolWeight?.let(numFormatInputs.format),
                    valueTransformer: (text) => text?.let(double.tryParse),
                    focusNode: emptyWeightFocusNode,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.spool_weight'.tr(),
                      helperText: 'pages.spoolman.spool_form.helper.empty_weight'.tr(),
                      helperMaxLines: 100,
                      hintText: (selectedFilament?.spoolWeight ?? selectedFilament?.vendor?.spoolWeight)
                          ?.let((it) => it.toString()),
                      suffixText: '[g]',
                    ),
                    onSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.emptyWeight.name, emptyWeightFocusNode, usedFocusNode),
                    textInputAction: TextInputAction.next,
                    validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                  ),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.used.name,
                    initialValue: sourceSpool?.usedWeight.let(numFormatInputs.format).only(mode == _FormMode.update),
                    valueTransformer: (text) => text?.let(double.tryParse),
                    focusNode: usedFocusNode,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.used_weight'.tr(),
                      helperText: 'pages.spoolman.spool_form.helper.used_weight'.tr(),
                      helperMaxLines: 100,
                      hintText: '0.0',
                      suffixText: '[g]',
                    ),
                    onSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.used.name, usedFocusNode, locationFocusNode),
                    textInputAction: TextInputAction.next,
                    validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                  ),

                  // Usage Details
                  SectionHeader(title: tr('pages.spoolman.property_sections.usage')),
                  FormBuilderDateTimePicker(
                    name: _SpoolFormFormComponent.firstUsed.name,
                    initialValue: sourceSpool?.firstUsed,
                    focusNode: firstUsedFocusNode,
                    keyboardType: TextInputType.datetime,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.first_used'.tr(),
                    ),
                    onFieldSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.firstUsed.name, firstUsedFocusNode, lastUsedFocusNode),
                    textInputAction: TextInputAction.next,
                  ),
                  FormBuilderDateTimePicker(
                    name: _SpoolFormFormComponent.lastUsed.name,
                    initialValue: sourceSpool?.lastUsed,
                    focusNode: lastUsedFocusNode,
                    keyboardType: TextInputType.datetime,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.last_used'.tr(),
                    ),
                    onFieldSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.lastUsed.name, lastUsedFocusNode, filamentFocusNode),
                    textInputAction: TextInputAction.next,
                  ),

                  // Meta Information
                  SectionHeader(title: tr('pages.spoolman.property_sections.additional')),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.location.name,
                    initialValue: sourceSpool?.location,
                    focusNode: locationFocusNode,
                    keyboardType: TextInputType.text,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.location'.tr(),
                      helperText: 'pages.spoolman.spool_form.helper.location'.tr(),
                      helperMaxLines: 100,
                    ),
                    onSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.location.name, locationFocusNode, lotFocusNode),
                    textInputAction: TextInputAction.next,
                  ),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.lot.name,
                    initialValue: sourceSpool?.lotNr,
                    focusNode: lotFocusNode,
                    keyboardType: TextInputType.text,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.lot_number'.tr(),
                      helperText: 'pages.spoolman.spool_form.helper.lot_number'.tr(),
                      helperMaxLines: 100,
                    ),
                    onSubmitted: (txt) => focusNext(_SpoolFormFormComponent.lot.name, lotFocusNode, commentFocusNode),
                    textInputAction: TextInputAction.next,
                  ),
                  FormBuilderTextField(
                    maxLines: null,
                    name: _SpoolFormFormComponent.comment.name,
                    initialValue: sourceSpool?.comment,
                    focusNode: commentFocusNode,
                    keyboardType: TextInputType.multiline,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.comment'.tr(),
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // body: _SpoolTab(),
    );
  }

  void focusNext(String key, FocusNode fieldNode, FocusNode nextNode) {
    if (_formKey.currentState?.fields[key]?.validate() == true) {
      nextNode.requestFocus();
    } else {
      fieldNode.requestFocus();
    }
  }
}

class _AppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCreate =
        ref.watch(_spoolFormPageControllerProvider(machineUUID).select((model) => model.mode != _FormMode.update));
    final title = isCreate
        ? tr('pages.spoolman.spool_form.create_page_title')
        : tr('pages.spoolman.spool_form.update_page_title');

    return AppBar(title: Text(title));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _Fab extends ConsumerWidget {
  const _Fab({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_SpoolFormPageControllerProvider(machineUUID).notifier);
    final (isSaving, selectedFilament) = ref.watch(
        _SpoolFormPageControllerProvider(machineUUID).select((model) => (model.isSaving, model.selectedFilament)));

    final themeData = Theme.of(context);

    return FloatingActionButton(
      onPressed: () {
        var formValid = _formKey.currentState?.saveAndValidate();
        if (selectedFilament == null) {
          final fLocale = FormBuilderLocalizations.of(context);

          _formKey.currentState?.fields[_SpoolFormFormComponent.filament.name]?.invalidate(fLocale.requiredErrorText);
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

@Riverpod(dependencies: [_initialSpool, _formMode, _initialFilament])
class _SpoolFormPageController extends _$SpoolFormPageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  _Model build(String machineUUID) {
    ref.keepAliveExternally(spoolmanServiceProvider(machineUUID));
    ref.listenSelf((prev, next) {
      logger.i('[SpoolFormPageController($machineUUID)] State changed: $next');
    });

    final filaments = ref.watch(filamentListProvider(machineUUID).selectAs((d) => d.items));

    final initialFilament = ref.watch(_initialFilamentProvider);
    final source = ref.watch(_initialSpoolProvider);
    final mode = ref.watch(_formModeProvider);

    return _Model(
      mode: mode,
      source: source,
      filaments: filaments,
      selectedFilament: stateOrNull?.selectedFilament ?? source?.filament ?? initialFilament,
    );
  }

  void onFormSubmitted(Map<String, dynamic>? formData, [int qty = 1]) {
    logger.i('[SpoolFormPageController($machineUUID)] Form submitted');
    if (formData == null || state.selectedFilament == null) {
      logger.w('[SpoolFormPageController($machineUUID)] Form data is null');
      return;
    }

    state = state.copyWith(isSaving: true);

    switch (state.mode) {
      case _FormMode.create:
      case _FormMode.copy:
        _create(formData, state.selectedFilament!, qty);
        break;
      case _FormMode.update:
        _update(formData, state.selectedFilament!);
        break;
    }
  }

  void onTapFilamentSelection() async {
    if (state.filaments.valueOrNull == null) return;
    final filaments = state.filaments.requireValue;
    final locale = ref.read(activeLocaleProvider);
    final numberFormat = NumberFormat.decimalPattern(locale.toStringWithSeparator());

    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        isScrollControlled: true,
        data: SelectionBottomSheetArgs<GetFilament>(
          options: [
            for (final filament in filaments.sortedBy((e) {
              if (e.vendor == null) return 'zzz'; //Kinda hacky
              var out = e.vendor!.name;
              if (e.material != null) out = '$out - ${e.material}';
              if (e.name != null) out = '$out - ${e.name}';
              return out;
            }))
              SelectionOption(
                value: filament,
                selected: state.selectedFilament?.id == filament.id,
                label: filament.displayNameWithDetails(numberFormat),
                subtitle: filament.vendor?.name,
                leading: SpoolWidget(color: filament.colorHex, height: 30),
              ),
          ],
          title: const Text('pages.spoolman.filament.one').tr(),
        ),
      ),
    );

    if (!res.confirmed || res.data is! GetFilament) return;
    final resFila = res.data as GetFilament;
    state = state.copyWith(selectedFilament: resFila);
  }

  Future<void> _create(Map<String, dynamic> formData, GetFilament filament, int qty) async {
    final dto = _createDtoFromForm(formData, filament);
    logger.i('[SpoolFormPageController($machineUUID)] Create DTO: $dto');
    final entityName = plural('pages.spoolman.spool', qty);
    try {
      final res = await Future.wait(List.generate(qty, (_) => _spoolmanService.createSpool(dto)));
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.create.success.title', args: [entityName]),
        message: plural('pages.spoolman.create.success.message', qty, args: [entityName]),
      ));
      _goRouter.pop(res);
    } catch (e, s) {
      logger.e('[SpoolFormPageController($machineUUID)] Error while saving.', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.create.error.title', args: [entityName]),
        message: tr('pages.spoolman.create.error.message'),
      ));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> _update(Map<String, dynamic> formData, GetFilament filament) async {
    final dto = _updateDtoFromForm(formData, filament, state.source!);
    logger.i('[SpoolFormPageController($machineUUID)] Update DTO: $dto');
    final entityName = tr('pages.spoolman.spool.one');
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
      final updated = await _spoolmanService.updateSpool(dto);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.update.success.title', args: [entityName]),
        message: tr('pages.spoolman.update.success.message', args: [entityName]),
      ));
      _goRouter.pop(updated);
    } catch (e, s) {
      logger.e('[SpoolFormPageController($machineUUID)] Error while saving.', e, s);
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

  CreateSpool _createDtoFromForm(Map<String, dynamic> formData, GetFilament filament) {
    return CreateSpool(
      firstUsed: formData[_SpoolFormFormComponent.firstUsed.name],
      lastUsed: formData[_SpoolFormFormComponent.lastUsed.name],
      filament: filament,
      price: formData[_SpoolFormFormComponent.price.name],
      initialWeight: formData[_SpoolFormFormComponent.initialWeight.name],
      spoolWeight:
          formData[_SpoolFormFormComponent.emptyWeight.name] ?? filament.spoolWeight ?? filament.vendor?.spoolWeight,
      usedWeight: formData[_SpoolFormFormComponent.used.name],
      location: formData[_SpoolFormFormComponent.location.name],
      lotNr: formData[_SpoolFormFormComponent.lot.name],
      comment: formData[_SpoolFormFormComponent.comment.name],
    );
  }

  UpdateSpool? _updateDtoFromForm(Map<String, dynamic> formData, GetFilament filament, GetSpool source) {
    final firstUsed = formData[_SpoolFormFormComponent.firstUsed.name];
    final lastUsed = formData[_SpoolFormFormComponent.lastUsed.name];
    final initialWeight = formData[_SpoolFormFormComponent.initialWeight.name];
    final spoolWeight = formData[_SpoolFormFormComponent.emptyWeight.name] ??
        (filament.spoolWeight ?? filament.vendor?.spoolWeight).only(source.filament.id != filament.id);
    final price = formData[_SpoolFormFormComponent.price.name];
    final usedWeight = formData[_SpoolFormFormComponent.used.name] as double?;
    final location = formData[_SpoolFormFormComponent.location.name];
    final lotNr = formData[_SpoolFormFormComponent.lot.name];
    final comment = formData[_SpoolFormFormComponent.comment.name];

    final usedWeightChanged =
        usedWeight != null && usedWeight != source.usedWeight && !usedWeight.closeTo(source.usedWeight, 0.01);

    // If no changes were made, return null
    if (filament.id == source.filament.id &&
        firstUsed == source.firstUsed &&
        lastUsed == source.lastUsed &&
        initialWeight == source.initialWeight &&
        spoolWeight == source.spoolWeight &&
        price == source.price &&
        !usedWeightChanged &&
        location == source.location &&
        lotNr == source.lotNr &&
        comment == source.comment) return null;

    return UpdateSpool(
      id: source.id,
      filament: source.filament.id == filament.id ? null : filament,
      firstUsed: source.firstUsed == firstUsed ? null : firstUsed,
      lastUsed: source.lastUsed == lastUsed ? null : lastUsed,
      initialWeight: source.initialWeight == initialWeight ? null : initialWeight,
      spoolWeight: source.spoolWeight == spoolWeight ? null : spoolWeight,
      price: source.price == price ? null : price,
      usedWeight: !usedWeightChanged ? null : usedWeight,
      location: source.location == location ? null : location,
      lotNr: source.lotNr == lotNr ? null : lotNr,
      comment: source.comment == comment ? null : comment,
    );
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required _FormMode mode,
    required GetSpool? source,
    required AsyncValue<List<GetFilament>> filaments,
    GetFilament? selectedFilament,
    @Default(false) isSaving,
  }) = __Model;
}
