/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/remote_connection/add_remote_connection_sheet_controller.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';
import 'package:mobileraker/ui/screens/printers/components/http_headers.dart';

import '../../../screens/printers/components/section_header.dart';

class AddRemoteConnectionBottomSheet extends ConsumerWidget {
  const AddRemoteConnectionBottomSheet({
    Key? key,
    required this.args,
  }) : super(key: key);

  final AddRemoteConnectionSheetArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ProviderScope(
        overrides: [sheetArgsProvider.overrideWithValue(args)],
        child: const _AddRemoteConnectionBottomSheet(),
      ),
    );
  }
}

class _AddRemoteConnectionBottomSheet extends HookConsumerWidget {
  const _AddRemoteConnectionBottomSheet({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(addRemoteConnectionSheetControllerProvider.notifier);
    var initalIndex =
        ref.watch(addRemoteConnectionSheetControllerProvider.select((value) => value.remoteInterface != null ? 1 : 0));

    var tabController = useTabController(initialLength: 2, initialIndex: initalIndex);

    var mediaQuery = MediaQuery.of(context);
    var themeData = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: themeData.colorScheme.primary,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  labelColor: themeData.colorScheme.onPrimary,
                  unselectedLabelColor: themeData.colorScheme.onPrimary.withOpacity(0.3),
                  controller: tabController,
                  indicatorColor: themeData.colorScheme.onPrimary,
                  automaticIndicatorColorAdjustment: false,
                  tabs: const [
                    Tab(text: 'OctoEverywhere'),
                    Tab(text: 'Manual'),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.close,
                icon: Icon(
                  Icons.close,
                  color: themeData.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: AnimatedSize(
            alignment: Alignment.bottomCenter,
            duration: kThemeChangeDuration,
            // curve: Curves.easeOutCubic,
            child: ConstraintsTransformBox(
              constraintsTransform: (BoxConstraints x) {
                double height = x.maxHeight * 0.8 + mediaQuery.viewInsets.bottom;

                return x.tighten(height: height);
              },
              child: FormBuilder(
                key: ref.watch(formKeyProvider),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Padding(
                  padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
                  child: TabBarView(
                    controller: tabController,
                    children: const [
                      _OctoTab(),
                      _ManualTab(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OctoTab extends ConsumerWidget {
  const _OctoTab({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(addRemoteConnectionSheetControllerProvider.notifier);
    var model = ref.watch(addRemoteConnectionSheetControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80, maxWidth: 80, minHeight: 40, minWidth: 40),
            child: SvgPicture.asset(
              'assets/vector/oe_logo.svg',
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'bottom_sheets.add_remote_con.octoeverywehre.description',
            textAlign: TextAlign.center,
          ).tr(),
          const Spacer(),
          if (model.octoEverywhere == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: OctoEveryWhereBtn(
                title: 'Link OctoEverywhere',
                onPressed: controller.linkOcto,
              ),
            ),
          if (model.octoEverywhere != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: OctoEveryWhereBtn(
                title: 'Unlink OctoEverywhere',
                onPressed: () => controller.removeRemoteConnection(true),
              ),
            ),
          Text(
            'bottom_sheets.add_remote_con.octoeverywehre.disclosure',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ).tr(),
        ],
      ),
    );
  }
}

class _ManualTab extends ConsumerWidget {
  const _ManualTab({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(addRemoteConnectionSheetControllerProvider.notifier);
    var model = ref.watch(addRemoteConnectionSheetControllerProvider.select((value) => value.remoteInterface));

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: ListView(
            padding: const EdgeInsets.all(8.0),
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: SvgPicture.asset(
                  'assets/vector/undraw_server_cluster_jwwq.svg',
                  height: 120,
                ),
              ),
              const Text(
                'bottom_sheets.add_remote_con.manual.description',
                textAlign: TextAlign.center,
              ).tr(),
              SectionHeader(title: tr('pages.setting.general.title')),
              FormBuilderTextField(
                name: 'alt.uri',
                decoration: InputDecoration(
                    labelText: tr('bottom_sheets.add_remote_con.manual.address_label'),
                    helperText: tr('bottom_sheets.add_remote_con.manual.address_hint')),
                initialValue: model?.remoteUri.toString(),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.url(requireTld: false),
                ]),
              ),
              FormBuilderTextField(
                keyboardType: const TextInputType.numberWithOptions(),
                decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.timeout_label'.tr(),
                    helperText: 'pages.printer_edit.general.timeout_helper'.tr(),
                    helperMaxLines: 3,
                    suffixText: 's'),
                name: 'alt.remoteTimeout',
                initialValue: (model?.timeout ?? 10).toString(),
                valueTransformer: (String? text) => text?.let(int.tryParse) ?? 10,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.min(0),
                  FormBuilderValidators.max(600),
                  FormBuilderValidators.integer(),
                ]),
              ),
              HttpHeaders(
                initialValue: model?.httpHeaders ?? const {},
              ),
              if (model != null)
                TextButton.icon(
                  onPressed: () => controller.removeRemoteConnection(false),
                  label: const Text('general.remove').tr(),
                  icon: const Icon(Icons.delete_forever_sharp),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: FullWidthButton(
            onPressed: controller.saveManual,
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ),
      ],
    );
  }
}
