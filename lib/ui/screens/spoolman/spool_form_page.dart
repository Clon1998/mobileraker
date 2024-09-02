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
import 'package:mobileraker_pro/service/moonraker/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/dto/create_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../printers/components/section_header.dart';

part 'spool_form_page.freezed.dart';
part 'spool_form_page.g.dart';

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
GetSpool? _spool(_SpoolRef ref) {
  throw UnimplementedError();
}

class SpoolFormPage extends StatelessWidget {
  const SpoolFormPage({super.key, required this.machineUUID, this.spool, this.isCopy = false});

  final String machineUUID;
  final GetSpool? spool;
  final bool isCopy;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // Make sure we are able to access the vendor in all places
      overrides: [_spoolProvider.overrideWithValue(spool)],
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
    final numFormat = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());
    final controller = ref.watch(_SpoolFormPageControllerProvider(machineUUID).notifier);
    final (sourceSpool, selectedFilament) = ref
        .watch(_SpoolFormPageControllerProvider(machineUUID).select((model) => (model.source, model.selectedFilament)));

    useEffect(
      () {
        _formKey.currentState?.fields[_SpoolFormFormComponent.filament.name]
            ?.didChange(selectedFilament?.displayNameWithDetails(numFormat));
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
                    initialValue: selectedFilament?.displayNameWithDetails(numFormat),
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
                    initialValue: sourceSpool?.price?.let(numFormat.format),
                    valueTransformer: (text) => text?.let(double.tryParse),
                    focusNode: priceFocusNode,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.price'.tr(),
                      helperText: 'pages.spoolman.spool_form.helper.price'.tr(),
                      helperMaxLines: 100,
                      hintText: (selectedFilament?.price)?.let(numFormat.format),
                      suffixText: ref.watch(spoolmanCurrencyProvider(machineUUID)),
                    ),
                    onSubmitted: (txt) =>
                        focusNext(_SpoolFormFormComponent.price.name, priceFocusNode, initialWeightFocusNode),
                    textInputAction: TextInputAction.next,
                    validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                  ),
                  FormBuilderTextField(
                    name: _SpoolFormFormComponent.initialWeight.name,
                    initialValue: sourceSpool?.initialWeight?.let(numFormat.format),
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
                    initialValue: sourceSpool?.spoolWeight?.let(numFormat.format),
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
                    initialValue: sourceSpool?.usedWeight.let(numFormat.format),
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

class _AppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('pages.spoolman.spool_form.create_page_title').tr(),
    );
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

@Riverpod(dependencies: [_spool])
class _SpoolFormPageController extends _$SpoolFormPageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  _Model build(String machineUUID) {
    ref.keepAliveExternally(spoolmanServiceProvider(machineUUID));

    final filaments = ref.watch(filamentListProvider(machineUUID).selectAs((d) => d.items));

    var source = ref.watch(_spoolProvider);
    return _Model(source: source, filaments: filaments, selectedFilament: source?.filament);
  }

  Future<void> onFormSubmitted(Map<String, dynamic>? formData, [int qty = 1]) async {
    logger.i('[SpoolFormPageController($machineUUID)] Form submitted');
    if (formData == null || state.selectedFilament == null) {
      logger.w('[SpoolFormPageController($machineUUID)] Form data is null');
      return;
    }

    state = state.copyWith(isSaving: true);
    final dto = _dtoFromForm(formData, state.selectedFilament!);
    logger.i('CreateSpool DTO: ${dto.toJson()}');
    try {
      await Future.wait(List.generate(qty, (_) => _spoolmanService.createSpool(dto)));
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.create.success.title', args: [plural('pages.spoolman.spool', qty)]),
        message: plural('pages.spoolman.create.success.message', qty, args: [plural('pages.spoolman.spool', qty)]),
      ));
      _goRouter.pop();
    } catch (e, s) {
      logger.e('[SpoolFormPageController($machineUUID)] Error while saving.', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.create.error.title', args: [plural('pages.spoolman.spool', qty)]),
        message: tr('pages.spoolman.create.error.message'),
      ));
    } finally {
      state = state.copyWith(isSaving: false);
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

  CreateSpool _dtoFromForm(Map<String, dynamic> formData, GetFilament filament) {
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
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required GetSpool? source,
    required AsyncValue<List<GetFilament>> filaments,
    GetFilament? selectedFilament,
    @Default(false) isSaving,
  }) = __Model;
}
