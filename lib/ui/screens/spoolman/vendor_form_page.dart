/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/moonraker/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/dto/create_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/vendor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../printers/components/section_header.dart';

part 'vendor_form_page.freezed.dart';
part 'vendor_form_page.g.dart';

enum _VendorFormFormComponent {
  name,
  spoolWeight,
  externalId,
  comment,
}

class VendorFormPage extends StatelessWidget {
  const VendorFormPage({super.key, required this.machineUUID, this.vendor, this.isCopy = false});

  final String machineUUID;
  final Vendor? vendor;
  final bool isCopy;

  @override
  Widget build(BuildContext context) {
    return _VendorFormPage(machineUUID: machineUUID);
  }
}

final _formKey = GlobalKey<FormBuilderState>();

class _VendorFormPage extends HookConsumerWidget {
  const _VendorFormPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameFocusNode = useFocusNode();
    final spoolWeightFocusNode = useFocusNode();
    final commentFocusNode = useFocusNode();

    return Scaffold(
      appBar: _AppBar(),
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
                    maxLines: null,
                    name: _VendorFormFormComponent.comment.name,
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

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('pages.spoolman.vendor_form.create_page_title').tr(),
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

@riverpod
class _VendorFormPageController extends _$VendorFormPageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  _Model build(String machineUUID) {
    return const _Model();
  }

  Future<void> onFormSubmitted(Map<String, dynamic>? formData) async {
    logger.i('[VendorFormPageController($machineUUID)] Form submitted');
    if (formData == null) {
      logger.w('[VendorFormPageController($machineUUID)] Form data is null');
      return;
    }

    state = state.copyWith(isSaving: true);
    final dto = _dtoFromForm(formData);
    logger.i('CreateVendor DTO: ${dto.toJson()}');
    try {
      await _spoolmanService.createVendor(dto);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.create.success.title', args: [tr('pages.spoolman.vendor.one')]),
        message: tr('pages.spoolman.create.success.message.one', args: [tr('pages.spoolman.vendor.one')]),
      ));
      _goRouter.pop();
    } catch (e, s) {
      logger.e('[VendorFormPageController($machineUUID)] Error while saving', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.create.error.title', args: [tr('pages.spoolman.vendor.one')]),
        message: tr('pages.spoolman.create.error.message'),
      ));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  CreateVendor _dtoFromForm(Map<String, dynamic> formData) {
    return CreateVendor(
      name: formData[_VendorFormFormComponent.name.name],
      spoolWeight: formData[_VendorFormFormComponent.spoolWeight.name],
      externalId: formData[_VendorFormFormComponent.externalId.name],
      comment: formData[_VendorFormFormComponent.comment.name],
    );
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    @Default(false) isSaving,
  }) = __Model;
}
