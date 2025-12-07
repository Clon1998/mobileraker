/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

class SliderOrTextInput extends StatefulWidget {
  const SliderOrTextInput({
    super.key,
    required this.value,
    required this.prefixText,
    required this.onChange,
    this.numberFormat,
    this.maxValue = 2,
    this.minValue = 0,
    this.addToMax = false,
    this.unit,
    this.submitOnChange = false,
  });

  final ValueChanged<double>? onChange;
  final NumberFormat? numberFormat;
  final String prefixText;
  final double value;
  final double maxValue;
  final double minValue;
  final String? unit;
  final bool addToMax;

  /// If true, the value will be submitted to the [onChange] callback whenever the slider is moved and not only when the user releases the slider.
  final bool submitOnChange;

  @override
  SliderOrTextInputState createState() => SliderOrTextInputState();
}

class SliderOrTextInputState extends State<SliderOrTextInput> {
  late double sliderPos;
  late bool inputValid;
  late TextEditingController textEditingController;
  late FocusNode focusNode;
  late bool isTextFieldFocused;
  late CrossFadeState fadeState;
  late double lastSubmittedValue;

  late double stepsToAdd;
  late double maxValue;

  NumberFormat get _numberFormat => widget.numberFormat ?? NumberFormat.percentPattern();

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

    _updateValueFromWidget();

    isTextFieldFocused = false;
    fadeState = CrossFadeState.showFirst;

    inputValid = true;

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
  void didUpdateWidget(SliderOrTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _updateValueFromWidget();
    }
  }

  void _updateValueFromWidget() {
    lastSubmittedValue = widget.value;
    sliderPos = widget.value;
    _updateTextController(widget.value);
  }

  @override
  void dispose() {
    textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        // Do nothing. Its just used to "Absorb" the event
      },
      child: Row(
        children: [
          Flexible(
            child: AnimatedCrossFade(
              firstChild: InputDecorator(
                decoration: InputDecoration(
                  label: Text('${widget.prefixText}: ${_numberFormat.format(sliderPos)}'),
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
                  suffix: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(widget.unit ?? '%')),
                  errorText: !inputValid ? FormBuilderLocalizations.current.numericErrorText : null,
                ),
                enabled: widget.onChange != null,
                onSubmitted: _submitTextField,
                focusNode: focusNode,
                controller: textEditingController,
                textAlign: TextAlign.end,
                keyboardType: const TextInputType.numberWithOptions(),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              ),
              duration: kThemeAnimationDuration,
              crossFadeState: fadeState,
            ),
          ),
          AnimatedSwitcher(
            duration: kThemeAnimationDuration,
            child: switch (fadeState) {
              CrossFadeState.showFirst => IconButton(
                key: const ValueKey('edit'),
                icon: const Icon(Icons.edit),
                onPressed: inputValid && widget.onChange != null ? _toggle : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
              ),
              CrossFadeState.showSecond when isTextFieldFocused => IconButton(
                key: const ValueKey('checkmark'),
                icon: const Icon(Icons.check),
                onPressed: inputValid ? _onCheckmarkClick : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
              ),
              CrossFadeState.showSecond => IconButton(
                key: const ValueKey('sliders'),
                icon: const Icon(FlutterIcons.fingerprint_mco),
                onPressed: inputValid && widget.onChange != null ? _toggle : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
              ),
            },
          ),
        ],
      ),
    );
  }

  void _onSliderChanged(double v) {
    if (widget.submitOnChange) {
      _submit(v);
    }
    setState(() {
      sliderPos = v;
    });
  }

  void _onSliderDone(double v) {
    _submit(v);
    _onSliderChanged(v);
    if (widget.addToMax && v == maxValue) {
      setState(() {
        maxValue += stepsToAdd;
      });
    }
  }

  void _submitTextField(String value) {
    if (!inputValid) return;

    double perc = _numberFormat.parse(textEditingController.text).toDouble();
    _submit(perc);
  }

  void _onCheckmarkClick() {
    focusNode.unfocus();
    _submitTextField(textEditingController.text);
  }

  void _toggle() {
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

  void _updateTextController(double value) {
    textEditingController.text = _numberFormat.format(value).replaceAll(RegExp(r'[^0-9.,]'), '');
  }

  void _onFocusChanged() {
    _submitTextField(textEditingController.text);
  }

  void _submit(double value) {
    if (widget.onChange == null || lastSubmittedValue == value) return;
    lastSubmittedValue = value;
    widget.onChange!(value);
  }
}
