/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/responsive_limit.dart';
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
import 'package:mobileraker_pro/spoolman/dto/create_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/update_vendor.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../printers/components/section_header.dart';

part 'vendor_form_page.freezed.dart';
part 'vendor_form_page.g.dart';

enum _FormMode { create, update, copy }

enum _VendorFormFormComponent {
  name,
  spoolWeight,
  externalId,
  comment,
}

@Riverpod(dependencies: [])
GetVendor? _vendor(Ref ref) {
  throw UnimplementedError();
}

@Riverpod(dependencies: [])
_FormMode _formMode(Ref ref) {
  return _FormMode.create;
}

class VendorFormPage extends StatelessWidget {
  const VendorFormPage({super.key, required this.machineUUID, this.vendor, this.isCopy = false});

  final String machineUUID;
  final GetVendor? vendor;
  final bool isCopy;

  @override
  Widget build(BuildContext context) {
    var mode = isCopy ? _FormMode.copy : (vendor == null ? _FormMode.create : _FormMode.update);

    return ProviderScope(
      // Make sure we are able to access the vendor in all places
      overrides: [_vendorProvider.overrideWithValue(vendor), _formModeProvider.overrideWithValue(mode)],
      child: _VendorFormPage(machineUUID: machineUUID),
    );
  }
}

final _formKey = GlobalKey<FormBuilderState>();

class _VendorFormPage extends HookConsumerWidget {
  const _VendorFormPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceVendor = ref.watch(_vendorFormPageControllerProvider(machineUUID).select((model) => model.source));

    final numFormatInputs = NumberFormat('0.##', context.locale.toStringWithSeparator());

    final nameFocusNode = useFocusNode();
    final spoolWeightFocusNode = useFocusNode();
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
                  SectionHeader(title: tr('pages.spoolman.property_sections.basic')),
                  FormBuilderTextField(
                    name: _VendorFormFormComponent.name.name,
                    initialValue: sourceVendor?.name,
                    focusNode: nameFocusNode,
                    keyboardType: TextInputType.text,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(labelText: 'pages.spoolman.properties.name'.tr()),
                    validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
                    onSubmitted: (txt) =>
                        focusNext(_VendorFormFormComponent.name.name, nameFocusNode, spoolWeightFocusNode),
                    textInputAction: TextInputAction.next,
                  ),
                  FormBuilderTextField(
                    name: _VendorFormFormComponent.spoolWeight.name,
                    initialValue: sourceVendor?.spoolWeight?.let(numFormatInputs.format),
                    valueTransformer: (text) => text?.let(double.tryParse),
                    focusNode: spoolWeightFocusNode,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'pages.spoolman.properties.spool_weight'.tr(),
                      suffixText: '[g]',
                      helperText: tr('pages.spoolman.vendor_form.helper.empty_weight'),
                      helperMaxLines: 100,
                    ),
                    validator: FormBuilderValidators.compose([FormBuilderValidators.numeric()]),
                    onSubmitted: (txt) =>
                        focusNext(_VendorFormFormComponent.spoolWeight.name, spoolWeightFocusNode, commentFocusNode),
                    textInputAction: TextInputAction.next,
                  ),
                  SectionHeader(title: tr('pages.spoolman.property_sections.additional')),
                  FormBuilderTextField(
                    name: _VendorFormFormComponent.comment.name,
                    initialValue: sourceVendor?.comment,
                    maxLines: null,
                    focusNode: commentFocusNode,
                    keyboardType: TextInputType.multiline,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(labelText: 'pages.spoolman.properties.comment'.tr()),
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        ref.watch(_vendorFormPageControllerProvider(machineUUID).select((d) => d.mode != _FormMode.update));
    final title = isCreate
        ? tr('pages.spoolman.vendor_form.create_page_title')
        : tr('pages.spoolman.vendor_form.update_page_title');

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
    final controller = ref.watch(_VendorFormPageControllerProvider(machineUUID).notifier);
    final isSaving = ref.watch(_VendorFormPageControllerProvider(machineUUID).select((model) => model.isSaving));

    final themeData = Theme.of(context);

    return FloatingActionButton(
      onPressed: () {
        var formValid = _formKey.currentState?.saveAndValidate();
        if (formValid == true) {
          controller.onFormSubmitted(_formKey.currentState?.value);
        }
      }.unless(isSaving),
      child: isSaving ? CircularProgressIndicator(color: themeData.colorScheme.onPrimary) : const Icon(Icons.save_alt),
    );
  }
}

@Riverpod(dependencies: [_vendor, _formMode])
class _VendorFormPageController extends _$VendorFormPageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  _Model build(String machineUUID) {
    ref.keepAliveExternally(spoolmanServiceProvider(machineUUID));

    final source = ref.watch(_vendorProvider);
    final mode = ref.watch(_formModeProvider);
    return _Model(mode: mode, source: source);
  }

  Future<void> onFormSubmitted(Map<String, dynamic>? formData) async {
    logger.i('[VendorFormPageController($machineUUID)] Form submitted');
    if (formData == null) {
      logger.w('[VendorFormPageController($machineUUID)] Form data is null');
      return;
    }

    state = state.copyWith(isSaving: true);
    switch (state.mode) {
      case _FormMode.create:
      case _FormMode.copy:
        _create(formData);
        break;
      case _FormMode.update:
        _update(formData);
        break;
    }
  }

  Future<void> _create(Map<String, dynamic> formData) async {
    final dto = _createDtoFromForm(formData);
    logger.i('[VendorFormPageController($machineUUID)] Create DTO: $dto');
    final entityName = tr('pages.spoolman.vendor.one');
    try {
      final res = await _spoolmanService.createVendor(dto);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.create.success.title', args: [entityName]),
        message: tr('pages.spoolman.create.success.message.one', args: [entityName]),
      ));
      _goRouter.pop(res);
    } catch (e, s) {
      logger.e('[VendorFormPageController($machineUUID)] Error while saving.', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.create.error.title', args: [entityName]),
        message: tr('pages.spoolman.create.error.message'),
      ));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> _update(Map<String, dynamic> formData) async {
    final dto = _updateDtoFromForm(formData, state.source!);
    logger.i('[VendorFormPageController($machineUUID)] Update DTO: $dto');
    final entityName = tr('pages.spoolman.vendor.one');

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
      final updated = await _spoolmanService.updateVendor(dto);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.update.success.title', args: [entityName]),
        message: tr('pages.spoolman.update.success.message', args: [entityName]),
      ));
      _goRouter.pop(updated);
    } catch (e, s) {
      logger.e('[VendorFormPageController($machineUUID)] Error while saving.', e, s);
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

  CreateVendor _createDtoFromForm(Map<String, dynamic> formData) {
    return CreateVendor(
      name: formData[_VendorFormFormComponent.name.name],
      spoolWeight: formData[_VendorFormFormComponent.spoolWeight.name],
      externalId: formData[_VendorFormFormComponent.externalId.name],
      comment: formData[_VendorFormFormComponent.comment.name],
    );
  }

  UpdateVendor? _updateDtoFromForm(Map<String, dynamic> formData, GetVendor source) {
    final name = formData[_VendorFormFormComponent.name.name];
    final spoolWeight = formData[_VendorFormFormComponent.spoolWeight.name];
    final externalId = formData[_VendorFormFormComponent.externalId.name];
    final comment = formData[_VendorFormFormComponent.comment.name];

    // If no changes were made, return null
    if (name == source.name &&
        spoolWeight == source.spoolWeight &&
        externalId == source.externalId &&
        comment == source.comment) return null;

    return UpdateVendor(
      id: source.id,
      name: source.name == name ? null : name,
      spoolWeight: source.spoolWeight == spoolWeight ? null : spoolWeight,
      comment: source.comment == comment ? null : comment,
      externalId: source.externalId == externalId ? null : externalId,
    );
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required _FormMode mode,
    required GetVendor? source,
    @Default(false) isSaving,
  }) = __Model;
}
