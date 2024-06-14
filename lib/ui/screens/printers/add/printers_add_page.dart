/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/components/info_card.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_controller.dart';
import 'package:mobileraker/ui/screens/printers/components/http_headers.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:mobileraker/ui/screens/printers/components/ssl_settings.dart';
import 'package:mobileraker/util/validator/custom_form_builder_validators.dart';
import 'package:progress_indicators/progress_indicators.dart';

class PrinterAddPage extends HookConsumerWidget {
  const PrinterAddPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TabController tabController = useTabController(initialLength: 2);
    var nonSupError = ref.watch(printerAddViewControllerProvider.select((value) => value.nonSupporterError));
    return Scaffold(
      appBar: AppBar(title: const Text('pages.printer_add.title').tr()),
      body: SafeArea(
        child: (nonSupError != null)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SupporterOnlyFeature(
                    header: Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints.loose(const Size(256, 256)),
                        child: SvgPicture.asset(
                          'assets/vector/undraw_warning_re_eoyh.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    text: Text(nonSupError),
                  ),
                ),
              )
            : const Column(
                children: [
                  _AddPrinterStepperFlow(),
                  Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: ClampingScrollPhysics(),
                      child: _StepperBody(),
                    ),
                  ),
                  _StepperFooter(),
                ],
              ),
      ),
    );
  }
}

class _StepperBody extends ConsumerWidget {
  const _StepperBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(printerAddViewControllerProvider.notifier);
    var model = ref.watch(printerAddViewControllerProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: FormBuilder(
        canPop: model.step == 0 || model.step == 3,
        onPopInvoked: controller.onPopInvoked,
        key: ref.watch(formKeyProvider),
        child: AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          transitionBuilder: (child, anim) => SizeAndFadeTransition(
            sizeAxisAlignment: -1,
            sizeAndFadeFactor: anim,
            child: child,
          ),
          child: Center(child: ResponsiveLimit(child: stepperBody(model.step, model.isExpert))),
        ),
      ),
    );
  }

  Widget stepperBody(int stepperIndex, bool isExpert) => switch (stepperIndex) {
        0 => const _InputModeStepScreen(),
        1 => (isExpert) ? const _AdvancedInputStepScreen() : const _SimpleUrlInputStepScreen(),
        2 => const _TestConnectionStepScreen(),
        3 => const _ConfirmationStepScreen(),
        _ => Text('No step widget found for index $stepperIndex'),
      };
}

class _StepperFooter extends ConsumerWidget {
  const _StepperFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(printerAddViewControllerProvider);

    Widget? footer = switch (model.step) {
      1 => const _UrlInputStepFooter(),
      2 => const _TestConnectionStepFooter(),
      _ => null,
    };

    if (footer == null) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: footer,
        ),
      ],
    );
  }
}

class _AddPrinterStepperFlow extends HookConsumerWidget {
  const _AddPrinterStepperFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(printerAddViewControllerProvider.notifier);
    var model = ref.watch(printerAddViewControllerProvider);

    return EasyStepper(
      onStepReached: controller.onStepTapped,
      activeStep: model.step,
      showLoadingAnimation: false,
      enableStepTapping: model.step != 3,
      padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 0),
      showScrollbar: false,
      steps: [
        EasyStep(
          title: tr('pages.printer_add.steps.mode'),
          icon: const Icon(Icons.add_moderator_outlined),
        ),
        EasyStep(
          title: tr('pages.printer_add.steps.input'),
          icon: const Icon(Icons.settings_outlined),
        ),
        EasyStep(
          title: tr('pages.printer_add.steps.test'),
          icon: const Icon(Icons.settings_input_antenna_outlined),
          enabled: false,
        ),
        EasyStep(
          title: tr('pages.printer_add.steps.done'),
          icon: const Icon(Icons.done_outline),
          enabled: false,
        ),
      ],
    );
  }
}

class _InputModeStepScreen extends ConsumerWidget {
  const _InputModeStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(printerAddViewControllerProvider.notifier);

    var themeData = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints.loose(const Size(256, 256)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SvgPicture.asset(
              'assets/vector/undraw_maker_launch_re_rq81.svg',
              alignment: Alignment.center,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'pages.printer_add.select_mode.title',
            style: themeData.textTheme.labelLarge,
          ).tr(),
        ),
        Text(
          'pages.printer_add.select_mode.body',
          textAlign: TextAlign.justify,
          style: themeData.textTheme.bodySmall,
        ).tr(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FilledButton.icon(
              onPressed: () => controller.selectMode(false),
              icon: const Icon(Icons.person_outline),
              label: const Text('pages.printer_add.select_mode.simple').tr(),
            ),
            FilledButton.icon(
              onPressed: () => controller.selectMode(true),
              icon: const Icon(Icons.engineering_outlined),
              label: const Text('pages.printer_add.select_mode.advanced').tr(),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: controller.addFromOcto,
            icon: SvgPicture.asset(
              'assets/vector/oe_rocket.svg',
              width: 24,
              height: 24,
            ),
            label: const Text('pages.printer_add.select_mode.add_via_oe').tr(),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: controller.addFromObico,
            icon: SvgPicture.asset(
              'assets/vector/obico_logo.svg',
              width: 24,
              height: 24,
            ),
            label: const Text('pages.printer_add.select_mode.add_via_obico').tr(),
          ),
        ),
        // OctoEveryWhereBtn(
        //     title: 'Add using OctoEverywhere', onPressed: () => null),
      ],
    );
  }
}

class _SimpleUrlInputStepScreen extends HookConsumerWidget {
  const _SimpleUrlInputStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simpleFormState = ref.watch(simpleFormControllerProvider);
    final simpleFormController = ref.watch(simpleFormControllerProvider.notifier);

    final nameFocusNode = useFocusNode();
    final addFocusNode = useFocusNode();
    final apiFocusNode = useFocusNode();

    var scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoCard(
          leading: const Icon(Icons.info_outline),
          title: const Text('pages.printer_add.simple_form.hint_title').tr(),
          body: const Text(
            'pages.printer_add.simple_form.hint_body',
            textAlign: TextAlign.justify,
          ).tr(),
        ),
        SectionHeader(title: tr('pages.setting.general.title')),
        FormBuilderTextField(
          focusNode: nameFocusNode,
          keyboardType: TextInputType.text,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.general.displayname'.tr(),
          ),
          name: 'simple.name',
          initialValue: tr('pages.printer_add.initial_name'),
          validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
          onSubmitted: (txt) => simpleFormController.focusNext('simple.name', nameFocusNode, addFocusNode),
          textInputAction: TextInputAction.next,
        ),
        FormBuilderTextField(
          focusNode: addFocusNode,
          keyboardType: TextInputType.url,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          // initialValue: simpleFormState.httpUri?.skipScheme(),
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.general.printer_addr'.tr(),
            hintText: tr('pages.printer_add.simple_form.url_hint'),
            prefix: InkWell(
              onTap: simpleFormController.toggleProtocol,
              child: Text(
                simpleFormState.scheme,
                style: TextStyle(color: scheme.secondary),
              ),
            ),
          ),
          name: 'simple.url',
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.url(requireTld: false),
            MobilerakerFormBuilderValidator.simpleUrl(),
          ]),
          onSubmitted: (txt) => simpleFormController.focusNext('simple.url', addFocusNode, apiFocusNode),
          textInputAction: TextInputAction.next,
        ),
        Row(
          children: [
            Flexible(
              child: FormBuilderTextField(
                focusNode: apiFocusNode,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'pages.printer_edit.general.moonraker_api_key'.tr(),
                  helperText: 'pages.printer_edit.general.moonraker_api_desc'.tr(),
                  helperMaxLines: 3,
                ),
                name: 'simple.apikey',
                textInputAction: TextInputAction.done,
                onSubmitted: (txt) => simpleFormController.proceed(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_sharp),
              onPressed: () => simpleFormController.openQrScanner(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _UrlInputStepFooter extends ConsumerWidget {
  const _UrlInputStepFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isExpert = ref.watch(
      printerAddViewControllerProvider.select((value) => value.isExpert),
    );

    var proceed = isExpert
        ? ref.watch(advancedFormControllerProvider.notifier).proceed
        : ref.watch(simpleFormControllerProvider.notifier).proceed;

    return _FlowControlButtons(
      proceed: proceed,
      proceedIcon: const Icon(FlutterIcons.rocket1_ant),
      proceedLabel: const Text('pages.printer_add.test_connection.button').tr(),
    );
  }
}

class _AdvancedInputStepScreen extends HookConsumerWidget {
  const _AdvancedInputStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var advancedFormState = ref.watch(advancedFormControllerProvider);
    var advancedFormController = ref.watch(advancedFormControllerProvider.notifier);

    final nameFocusNode = useFocusNode();
    final addressFocusNode = useFocusNode();
    final timeoutFocusNode = useFocusNode();
    final apiFocusNode = useFocusNode();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoCard(
          leading: const Icon(Icons.warning_amber),
          title: const Text('pages.printer_add.advanced_form.hint_title').tr(),
          body: const Text(
            'pages.printer_add.advanced_form.hint_body',
            textAlign: TextAlign.justify,
          ).tr(),
        ),
        SectionHeader(title: tr('pages.setting.general.title')),
        FormBuilderTextField(
          focusNode: nameFocusNode,
          keyboardType: TextInputType.text,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.general.displayname'.tr(),
          ),
          name: 'advanced.name',
          initialValue: tr('pages.printer_add.initial_name'),
          validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
          onSubmitted: (txt) => advancedFormController.focusNext('advanced.name', nameFocusNode, addressFocusNode),
          textInputAction: TextInputAction.next,
        ),
        FormBuilderTextField(
          focusNode: addressFocusNode,
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.general.printer_addr'.tr(),
            hintText: 'E.g.: 192.1.1.1',
            helperText: tr('pages.printer_add.advanced_form.http_helper'),
          ),
          name: 'advanced.http',
          autovalidateMode: AutovalidateMode.onUserInteraction,
          // initialValue: advancedFormState.httpUri?.toString(),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.url(
              requireTld: false,
              requireProtocol: false,
              protocols: ['http', 'https'],
            ),
          ]),
          onSubmitted: (txt) => advancedFormController.focusNext('advanced.http', addressFocusNode, timeoutFocusNode),
          textInputAction: TextInputAction.next,
        ),
        FormBuilderTextField(
          focusNode: timeoutFocusNode,
          keyboardType: const TextInputType.numberWithOptions(),
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.general.timeout_label'.tr(),
            helperText: 'pages.printer_edit.general.timeout_helper'.tr(),
            helperMaxLines: 3,
            suffixText: 's',
          ),
          name: 'advanced.localTimeout',
          initialValue: '5',
          valueTransformer: (String? text) => text?.let(int.tryParse) ?? 3,
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.min(0),
            FormBuilderValidators.max(600),
            FormBuilderValidators.integer(),
          ]),
          onSubmitted: (txt) =>
              advancedFormController.focusNext('advanced.localTimeout', timeoutFocusNode, apiFocusNode),
          textInputAction: TextInputAction.next,
        ),
        SectionHeader(
          title: tr('pages.printer_add.advanced_form.section_security'),
        ),
        Row(
          children: [
            Flexible(
              child: FormBuilderTextField(
                focusNode: apiFocusNode,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'pages.printer_edit.general.moonraker_api_key'.tr(),
                  helperText: 'pages.printer_edit.general.moonraker_api_desc'.tr(),
                  helperMaxLines: 3,
                ),
                name: 'advanced.apikey',
                onSubmitted: (txt) => advancedFormController.focusNext('advanced.localTimeout', apiFocusNode),
                textInputAction: TextInputAction.next,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_sharp),
              onPressed: () => advancedFormController.openQrScanner(
                context,
              ),
            ),
          ],
        ),
        Flexible(
          child: SslSettings(
            initialCertificateDER: advancedFormState.pinnedCertificateDER,
            initialTrustSelfSigned: advancedFormState.trustUntrustedCertificate,
          ),
        ),
        HttpHeaders(initialValue: advancedFormState.headers),
      ],
    );
  }
}

class _TestConnectionStepScreen extends HookConsumerWidget {
  const _TestConnectionStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(testConnectionControllerProvider);
    var themeData = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr('pages.printer_add.test_connection.section_connection'),
        ),
        InputDecorator(
          decoration: InputDecoration(
            labelText: tr('pages.printer_add.test_connection.http_url_label'),
            border: InputBorder.none,
          ),
          child: Text(model.httpUri?.toString() ?? 'MISSING?'),
        ),
        InputDecorator(
          decoration: InputDecoration(
            labelText: tr('pages.printer_add.test_connection.ws_url_label'),
            border: InputBorder.none,
          ),
          child: Text(model.wsUri?.toString() ?? 'MISSING?'),
        ),
        SectionHeader(
          title: tr('pages.printer_add.test_connection.section_test'),
        ),
        InputDecorator(
          decoration: InputDecoration(
            labelText: tr('pages.printer_add.test_connection.http_label'),
            border: InputBorder.none,
            suffixIcon: Icon(
              Icons.radio_button_on,
              size: 10,
              color: model.httpStateColor(themeData),
            ),
            errorText: model.httpError,
            // errorText: 'Some Ws Error text',
            errorMaxLines: 3,
          ),
          child: model.httpState == null
              ? FadingText(tr('pages.printer_add.test_connection.awaiting'))
              : Text(model.httpStateText),
        ),
        InputDecorator(
          decoration: InputDecoration(
            labelText: tr('pages.printer_add.test_connection.ws_label'),
            border: InputBorder.none,
            suffixIcon: Icon(
              Icons.radio_button_on,
              size: 10,
              color: model.wsStateColor(themeData),
            ),
            errorText: model.wsError,
            errorMaxLines: 3,
          ),
          child: (model.wsState == ClientState.connecting)
              ? FadingText(tr('pages.printer_add.test_connection.awaiting'))
              : Text(model.wsStateText),
        ),
      ],
    );
  }
}

class _TestConnectionStepFooter extends ConsumerWidget {
  const _TestConnectionStepFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(testConnectionControllerProvider.notifier);
    var model = ref.watch(testConnectionControllerProvider);
    var themeData = Theme.of(context);

    return Column(
      children: [
        if (model.hasResults && !model.combinedResult)
          Text(
            'pages.printer_add.test_connection.proceed_warning',
            style: themeData.textTheme.bodySmall,
            textAlign: TextAlign.justify,
          ).tr(),
        _FlowControlButtons(
          proceed: model.hasResults ? controller.proceed : null,
          proceedIcon: (model.hasResults && !model.combinedResult)
              ? const Text('pages.printer_add.test_connection.continue_anyway').tr()
              : const Text('pages.printer_add.test_connection.continue').tr(),
          proceedLabel: const Icon(Icons.navigate_next),
          proceedStyle: (model.hasResults && !model.combinedResult)
              ? FilledButton.styleFrom(
                  backgroundColor: themeData.colorScheme.error,
                  foregroundColor: themeData.colorScheme.onError,
                )
              : null,
        ),
      ],
    );
  }
}

class _ConfirmationStepScreen extends ConsumerWidget {
  const _ConfirmationStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(printerAddViewControllerProvider);
    var controller = ref.watch(printerAddViewControllerProvider.notifier);
    var themeData = Theme.of(context);
    if (model.addedMachine == null) {
      return SpinKitWave(color: themeData.colorScheme.primary);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'pages.printer_add.confirmed.title',
          style: themeData.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ).tr(args: [model.machineToAdd!.name]),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints.loose(const Size(256, 256)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SvgPicture.asset(
                'assets/vector/undraw_astronaut_re_8c33.svg',
                // 'assets/vector/undraw_confirmed_re_sef7.svg',
              ),
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: controller.goToDashboard,
          icon: const Icon(FlutterIcons.printer_3d_nozzle_mco),
          label: const Text('pages.printer_add.confirmed.to_dashboard').tr(),
        ),
      ],
    );
  }
}

class _FlowControlButtons extends ConsumerWidget {
  const _FlowControlButtons({
    super.key,
    this.proceed,
    this.proceedIcon,
    required this.proceedLabel,
    this.proceedStyle,
  });

  final VoidCallback? proceed;
  final Widget? proceedIcon;
  final Widget proceedLabel;
  final ButtonStyle? proceedStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        FilledButton.tonalIcon(
          onPressed: ref.watch(printerAddViewControllerProvider.notifier).previousStep,
          icon: const Icon(Icons.navigate_before),
          label: Text(MaterialLocalizations.of(context).backButtonTooltip),
        ),
        FilledButton.tonalIcon(
          style: proceedStyle,
          onPressed: proceed,
          icon: proceedIcon ?? const Icon(Icons.navigate_next),
          label: proceedLabel,
        ),
      ],
    );
  }
}
