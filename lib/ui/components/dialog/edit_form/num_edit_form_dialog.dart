/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/double_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';

import 'num_edit_form_controller.dart';

class NumEditFormDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const NumEditFormDialog(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    NumberEditDialogArguments data = request.data;

    return ProviderScope(
      overrides: [
        dialogCompleter.overrideWithValue(completer),
        initialFormType.overrideWithValue(request.type),
        numFraction.overrideWithValue(data.fraction),
        numEditFormDialogController
      ],
      child: _FormEditDialog(request: request, data: data),
    );
  }
}

class _FormEditDialog extends HookConsumerWidget {
  const _FormEditDialog({
    Key? key,
    required this.request,
    required this.data,
  }) : super(key: key);

  final DialogRequest request;
  final NumberEditDialogArguments data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isValid = useState(true);

    var themeData = Theme.of(context);

    return Dialog(
      child: FormBuilder(
        autovalidateMode: AutovalidateMode.always,
        key: ref.watch(numEditFormKeyProvider),
        onChanged: () {
          isValid.value =
              ref.read(numEditFormKeyProvider).currentState!.validate();
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // To make the card compact
            children: <Widget>[
              Text(
                request.title!,
                style: themeData.textTheme.titleLarge,
              ),
              AnimatedCrossFade(
                duration: kThemeAnimationDuration,
                crossFadeState: (ref.watch(numEditFormDialogController) ==
                        DialogType.numEdit)
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _NumField(
                  description: request.body,
                  initialValue: data.current,
                  upperBorder: data.max,
                  lowerBorder: data.min,
                  frac: data.fraction,
                ),
                secondChild: RangeEditSlider(
                  description: request.body,
                  initialValue: data.current,
                  upperBorder: data.max,
                  lowerBorder: data.min,
                  frac: data.fraction,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: ref
                        .read(numEditFormDialogController.notifier)
                        .onFormDecline,
                    child: Text(request.cancelBtn!),
                  ),
                  IconButton(
                    onPressed: isValid.value
                        ? ref
                            .read(numEditFormDialogController.notifier)
                            .switchToOtherVariant
                        : null,
                    color: isValid.value
                        ? themeData.textTheme.bodySmall?.color
                        : themeData.disabledColor,
                    iconSize: 18,
                    icon: AnimatedSwitcher(
                      duration: kThemeAnimationDuration,
                      transitionBuilder: (child, anim) => RotationTransition(
                        turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: ref.watch(numEditFormDialogController) ==
                              DialogType.rangeEdit
                          ? const Icon(Icons.text_fields,
                              key: ValueKey('tf'))
                          : const Icon(Icons.straighten,
                              key: ValueKey('unlock')),
                    ),
                  ),
                  TextButton(
                    onPressed: isValid.value
                        ? ref
                            .read(numEditFormDialogController.notifier)
                            .onFormConfirm
                        : null,
                    child: Text(request.confirmBtn!),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final num initialValue;
  final num lowerBorder;
  final num? upperBorder;
  final int frac;
  final String? description;

  const _NumField(
      {Key? key,
      required this.initialValue,
      required this.lowerBorder,
      this.upperBorder,
      required this.frac,
      this.description})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      autofocus: true,
      validator: FormBuilderValidators.compose([
        if (upperBorder != null) FormBuilderValidators.max(upperBorder!),
        FormBuilderValidators.min(lowerBorder),
        FormBuilderValidators.numeric(),
        if (frac == 0) FormBuilderValidators.integer(),
        FormBuilderValidators.required()
      ]),
      valueTransformer: (String? text) => text == null ? 0 : num.tryParse(text),
      initialValue: initialValue.toStringAsFixed(frac),
      name: 'textValue',
      style: Theme.of(context).inputDecorationTheme.counterStyle,
      keyboardType:
          const TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        contentPadding: const EdgeInsets.all(8.0),
        labelText: description,
        helperText: _helperText(),
      ),
    );
  }

  String _helperText() {
    if (upperBorder == null) return 'Enter a value of at least $lowerBorder';

    return 'Enter a value between $lowerBorder and $upperBorder';
  }
}

class RangeEditSlider extends StatelessWidget {
  const RangeEditSlider(
      {Key? key,
      required this.initialValue,
      required this.lowerBorder,
      this.upperBorder,
      required this.frac,
      this.description})
      : super(key: key);

  final num initialValue;
  final num lowerBorder;
  final num? upperBorder;
  final int frac;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return FormBuilderSlider(
      name: 'rangeValue',
      initialValue: initialValue.toDouble().toPrecision(frac),
      min: lowerBorder.toDouble(),
      max: (upperBorder ?? 100).toDouble(),
      // divisions: (data.max + data.min.abs()).toInt(),
      autofocus: true,
      numberFormat: NumberFormat(
          frac == 0 ? "0" : "0.${List.filled(frac, '0').join()}",
          context.locale.languageCode),
    );
  }
}
