/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SliderOrTextInput extends ConsumerStatefulWidget {
  final ValueChanged<double>? onChange;
  final NumberFormat numberFormat;
  final String prefixText;
  final ProviderListenable<double> provider;
  final double maxValue;
  final double minValue;
  final String? unit;
  final bool addToMax;

  SliderOrTextInput({
    super.key,
    required this.provider,
    required this.prefixText,
    required this.onChange,
    NumberFormat? numberFormat,
    this.maxValue = 2,
    this.minValue = 0,
    this.addToMax = false,
    this.unit,
  }) : numberFormat = numberFormat ?? NumberFormat('0%');

  @override
  SliderOrTextInputState createState() => SliderOrTextInputState();
}

class SliderOrTextInputState extends ConsumerState<SliderOrTextInput> {
  late double sliderPos;
  late bool focusRequested;
  late bool inputValid;
  late TextEditingController textEditingController;
  late FocusNode focusNode;
  late bool isTextFieldFocused;
  late CrossFadeState fadeState;
  late double lastSubmittedValue;

  late double stepsToAdd;
  late double maxValue;

  NumberFormat get _numberFormat => widget.numberFormat;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    focusNode = FocusNode();
    textEditingController = TextEditingController();
    maxValue = widget.maxValue;
    stepsToAdd = (maxValue - widget.minValue) / 2;
    // Actual States

    //TODO: This needs to be moced to updateWidget as init state is NOT caled if provider changes!
    double initValue = ref.read(widget.provider);
    lastSubmittedValue = initValue;
    sliderPos = initValue;
    _updateTextController(initValue);

    isTextFieldFocused = false;
    fadeState = CrossFadeState.showFirst;

    // Helper States
    inputValid = true;

    // Setup listener
    focusNode.addListener(() {
      setState(() {
        if (isTextFieldFocused != focusNode.hasFocus) _onFocusChanged();
        isTextFieldFocused = focusNode.hasFocus;
      });
    });

    textEditingController.addListener(() {
      var text = textEditingController.text;

      setState(() {
        inputValid = text.isNotEmpty && RegExp(r'^\d+([.,])?\d*?$').hasMatch(text);
      });
    });
  }

  @override
  void dispose() {
    textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widget.provider, (previous, next) {
      if (next == lastSubmittedValue) return;
      lastSubmittedValue = next;
      sliderPos = next;
      _updateTextController(next);
    });

    return Row(
      children: [
        Flexible(
          child: AnimatedCrossFade(
            firstChild: InputDecorator(
              decoration: InputDecoration(
                label: Text(
                  '${widget.prefixText}: ${_numberFormat.format(sliderPos)}',
                ),
                isCollapsed: true,
                border: InputBorder.none,
              ),
              child: Slider(
                value: min(maxValue, sliderPos),
                onChanged: widget.onChange != null ? _onSliderChanged : null,
                onChangeEnd: widget.onChange != null ? _onSliderDone : null,
                max: maxValue,
                min: widget.minValue,
              ),
            ),
            secondChild: TextField(
              decoration: InputDecoration(
                prefixText: '${widget.prefixText}:',
                border: InputBorder.none,
                suffix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(widget.unit ?? '%'),
                ),
                errorText: !inputValid ? FormBuilderLocalizations.current.numericErrorText : null,
              ),
              enabled: widget.onChange != null,
              onSubmitted: _submitTextField,
              focusNode: focusNode,
              controller: textEditingController,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
            ),
            duration: kThemeAnimationDuration,
            crossFadeState: fadeState,
          ),
        ),
        AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          child: fadeState == CrossFadeState.showSecond && isTextFieldFocused
              ? IconButton(
                  key: const ValueKey('checkmark'),
                  icon: const Icon(Icons.check),
                  onPressed: inputValid ? _onCheckmarkClick : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
                )
              : IconButton(
                  key: const ValueKey('edit'),
                  icon: const Icon(Icons.edit),
                  onPressed: inputValid && widget.onChange != null ? _toggle : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
                ),
        ),
      ],
    );
  }

  _onSliderChanged(double v) {
    setState(() {
      sliderPos = v;
    });
  }

  _onSliderDone(double v) {
    _submit(v);
    _onSliderChanged(v);
    if (widget.addToMax && v == maxValue) {
      setState(() {
        maxValue += stepsToAdd;
      });
    }
  }

  _submitTextField(String value) {
    if (!inputValid) return;

    double perc = _numberFormat.parse(textEditingController.text).toDouble();
    _submit(perc);
  }

  _onCheckmarkClick() {
    focusNode.unfocus();
    _submitTextField(textEditingController.text);
  }

  _toggle() {
    setState(() {
      if (fadeState == CrossFadeState.showFirst) {
        _updateTextController(sliderPos);
        fadeState = CrossFadeState.showSecond;
        focusNode.requestFocus();
      } else {
        sliderPos = _numberFormat.parse(textEditingController.text).toDouble();
        fadeState = CrossFadeState.showFirst;
        focusNode.unfocus();
      }
    });
  }

  _updateTextController(double value) {
    textEditingController.text = _numberFormat.format(value).replaceAll(RegExp(r'[^0-9.,]'), '');
  }

  _onFocusChanged() {
    _submitTextField(textEditingController.text);
  }

  _submit(double value) {
    if (widget.onChange == null || lastSubmittedValue == value) return;
    lastSubmittedValue = value;
    widget.onChange!(value);
  }
}
