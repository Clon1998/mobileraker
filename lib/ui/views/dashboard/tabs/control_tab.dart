import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/refresh_printer.dart';
import 'package:mobileraker/ui/views/dashboard/tabs/control_tab_viewmodel.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_hooks/stacked_hooks.dart';

class ControlTab extends ViewModelBuilderWidget<ControlTabViewModel> {
  const ControlTab({Key? key}) : super(key: key);

  @override
  bool get disposeViewModel => false;

  @override
  bool get initialiseSpecialViewModelsOnce => true;

  @override
  Widget builder(
      BuildContext context, ControlTabViewModel model, Widget? child) {
    if (!model.isDataReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitRipple(
              color: Theme.of(context).colorScheme.secondary,
              size: 100,
            ),
            SizedBox(
              height: 30,
            ),
            FadingText('Fetching printer data'),
            // Text('Fetching printer ...')
          ],
        ),
      );
    }
    return PullToRefreshPrinter(
      child: ListView(
        key: PageStorageKey<String>('cTab'),
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          if (model.macroGroups.isNotEmpty) GcodeMacroCard(),
          if (model.isNotPrinting) ExtruderControlCard(),
          FansCard(),
          if (model.printerData.outputPins.isNotEmpty) PinsCard(),
          MultipliersCard(),
          LimitsCard(),
        ],
      ),
    );
  }

  @override
  ControlTabViewModel viewModelBuilder(BuildContext context) =>
      locator<ControlTabViewModel>();
}

class FansCard extends ViewModelWidget<ControlTabViewModel> {
  const FansCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ControlTabViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                FlutterIcons.fan_mco,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text('pages.dashboard.control.fan_card.title')
                  .plural(model.printerData.fans.length),
            ),
            AdaptiveHorizontalScroll(
              pageStorageKey: 'fans',
              children: buildFans(model, context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildFans(ControlTabViewModel model, BuildContext context) {
    List<Widget> rows = [];

    var printFan = model.printerData.printFan;
    rows.add(_FanTile(
        name: 'pages.dashboard.control.fan_card.part_fan'.tr(),
        speed: printFan.speed,
        onTap: model.klippyCanReceiveCommands ? model.onEditPartFan : null));

    for (NamedFan fan in model.filteredFans) {
      VoidCallback? f;
      if (fan is GenericFan) f = () => model.onEditGenericFan(fan);
      var row = _FanTile(
        name: beautifyName(fan.name),
        speed: fan.speed,
        onTap: model.klippyCanReceiveCommands ? f : null,
      );
      rows.add(row);
    }

    return rows;
  }
}

class _FanTile extends StatelessWidget {
  final String name;
  final double speed;
  final VoidCallback? onTap;

  const _FanTile({
    Key? key,
    required this.name,
    required this.speed,
    this.onTap,
  }) : super(key: key);

  String get fanSpeed {
    double fanPerc = speed * 100;
    if (speed > 0) return '${fanPerc.toStringAsFixed(0)} %';
    return 'general.off'.tr();
  }

  @override
  Widget build(BuildContext context) {
    double icoSize = 30;
    var w = speed > 0
        ? SpinningFan(size: icoSize)
        : Icon(
            FlutterIcons.fan_off_mco,
            size: icoSize,
          );

    return CardWithButton(
        child: Builder(builder: (context) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.caption),
                  Text(fanSpeed, style: Theme.of(context).textTheme.headline6),
                ],
              ),
              w,
            ],
          );
        }),
        buttonChild: onTap == null
            ? const Text('pages.dashboard.control.fan_card.static_fan_btn').tr()
            : const Text('general.set').tr(),
        onTap: onTap);
  }
}

class SpinningFan extends HookWidget {
  final double? size;

  SpinningFan({this.size});

  @override
  Widget build(BuildContext context) {
    AnimationController animationController =
        useAnimationController(duration: const Duration(seconds: 3))..repeat();
    return RotationTransition(
      turns: animationController,
      child: Icon(FlutterIcons.fan_mco, size: size),
    );
  }
}

class ExtruderControlCard extends ViewModelWidget<ControlTabViewModel> {
  const ExtruderControlCard({
    Key? key,
  }) : super(key: key, reactive: true);

  @override
  Widget build(BuildContext context, ControlTabViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
            title: Row(
              children: [
                Text('pages.dashboard.control.extrude_card.title').tr(),
                AnimatedOpacity(
                  opacity: model.extruderCanExtrude ? 0 : 1,
                  duration: kThemeAnimationDuration,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Tooltip(
                      child: Icon(
                        Icons.severe_cold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      message: tr(
                          'pages.dashboard.control.extrude_card.cold_extrude_error',
                          args: [model.extruderMinTemp.toStringAsFixed(0)]),
                    ),
                  ),
                )
              ],
            ),
            trailing: (model.printerData.extruderCount > 1)
                ? DropdownButton(
                    value: model.activeExtruder,
                    onChanged: model.klippyCanReceiveCommands
                        ? model.onExtruderSelected
                        : null,
                    items:
                        List.generate(model.printerData.extruderCount, (index) {
                      String name =
                          tr('pages.dashboard.control.extrude_card.title');
                      if (index > 0) name += ' $index';
                      return DropdownMenuItem(
                        child: Text(name),
                        value: index,
                      );
                    }))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed: model.klippyCanReceiveCommands &&
                                model.extruderCanExtrude
                            ? model.onRetractBtn
                            : null,
                        icon: Icon(FlutterIcons.minus_ant),
                        label:
                            Text('pages.dashboard.control.extrude_card.retract')
                                .tr(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed: model.klippyCanReceiveCommands &&
                                model.extruderCanExtrude
                            ? model.onDeRetractBtn
                            : null,
                        icon: Icon(FlutterIcons.plus_ant),
                        label:
                            Text('pages.dashboard.control.extrude_card.extrude')
                                .tr(),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${tr('pages.dashboard.control.extrude_card.extrude_len')} [mm]'),
                    ),
                    RangeSelector(
                        selectedIndex: model.selectedIndexRetractLength,
                        onSelected: model.onSelectedRetractChanged,
                        values: model.retractLengths
                            .map((e) => e.toString())
                            .toList()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GcodeMacroCard extends ViewModelWidget<ControlTabViewModel> {
  const GcodeMacroCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ControlTabViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(FlutterIcons.code_braces_mco),
            title: Text('pages.dashboard.control.macro_card.title').tr(),
            trailing: (model.macroGroups.length > 1)
                ? DropdownButton(
                    value: model.selectedGrp,
                    onChanged: model.klippyCanReceiveCommands
                        ? model.onMacroGroupSelected
                        : null,
                    items: model.macroGroups.map((e) {
                      return DropdownMenuItem(
                        child: Text(e.name),
                        value: e,
                      );
                    }).toList())
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: ChipTheme(
              data: ChipThemeData(
                  labelStyle:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  deleteIconColor: Theme.of(context).colorScheme.onPrimary),
              child: Wrap(
                spacing: 5.0,
                children: _generateGCodeChips(context, model),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _generateGCodeChips(
      BuildContext context, ControlTabViewModel model) {
    var themeData = Theme.of(context);
    var bgColActive = themeData.colorScheme.primary;

    List<GCodeMacro> macros = model.selectedGrp?.macros ?? [];
    return List<Widget>.generate(
      macros.length,
      (int index) {
        GCodeMacro macro = macros[index];
        bool disabled = (!model.klippyCanReceiveCommands ||
            (model.isPrinting && !macro.showWhilePrinting));
        return Visibility(
          visible: model.printerData.gcodeMacros.contains(macro.name) &&
              macro.visible,
          child: ActionChip(
            label: Text(macro.beautifiedName),
            backgroundColor: disabled ? themeData.disabledColor : bgColActive,
            onPressed: () => disabled ? null : model.onMacroPressed(macro),
          ),
        );
      },
    ).toList();
  }
}

class PinsCard extends ViewModelWidget<ControlTabViewModel> {
  const PinsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ControlTabViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                FlutterIcons.led_outline_mco,
              ),
              title: Text(plural('pages.dashboard.control.pin_card.title',
                  model.printerData.outputPins.length)),
            ),
            AdaptiveHorizontalScroll(
              pageStorageKey: 'pins',
              children: buildPins(
                model,
                context,
              ),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> buildPins(ControlTabViewModel model, BuildContext context) {
    List<Widget> rows = [];

    for (var pin in model.filteredPins) {
      var configForOutput = model.configForOutput(pin.name);
      var row = _PinTile(
        name: beautifyName(pin.name),
        value: pin.value * (configForOutput?.scale ?? 1),
        onTap: model.klippyCanReceiveCommands
            ? () => model.onEditPin(pin, configForOutput)
            : null,
      );
      rows.add(row);
    }
    return rows;
  }
}

class _PinTile extends StatelessWidget {
  final String name;

  /// Expect a value between 0-Scale!
  final double value;
  final VoidCallback? onTap;

  const _PinTile({
    Key? key,
    required this.name,
    required this.value,
    this.onTap,
  }) : super(key: key);

  String get pinValue {
    // double perc = value * 100;
    if (value == value.round()) return value.toStringAsFixed(0);
    if (value > 0) return value.toStringAsFixed(2);
    return 'general.off'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        child: Builder(builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.caption),
              Text(pinValue, style: Theme.of(context).textTheme.headlineSmall),
            ],
          );
        }),
        buttonChild: onTap == null
            ? const Text('pages.dashboard.control.pin_card.pin_btn').tr()
            : const Text('general.set').tr(),
        onTap: onTap);
  }
}

class MultipliersCard extends ViewModelWidget<ControlTabViewModel> {
  const MultipliersCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ControlTabViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(FlutterIcons.speedometer_slow_mco),
            title: Text('pages.dashboard.control.multipl_card.title').tr(),
            trailing: IconButton(
                onPressed: model.onToggleMultipliersLock,
                icon: AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: model.multipliersLocked
                      ? Icon(FlutterIcons.lock_faw, key: const ValueKey('lock'))
                      : Icon(FlutterIcons.unlock_faw,
                          key: const ValueKey('unlock')),
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              children: [
                _SliderOrTextInput(
                  initialValue: model.speedMultiplier,
                  prefixText: 'pages.dashboard.general.print_card.speed'.tr(),
                  onChange:
                      model.klippyCanReceiveCommands && !model.multipliersLocked
                          ? model.onEditedSpeedMultiplier
                          : null,
                ),
                _SliderOrTextInput(
                    initialValue: model.flowMultiplier,
                    prefixText:
                        'pages.dashboard.control.multipl_card.flow'.tr(),
                    onChange: model.klippyCanReceiveCommands &&
                            !model.multipliersLocked
                        ? model.onEditedFlowMultiplier
                        : null),
                _SliderOrTextInput(
                  initialValue: model.pressureAdvanced,
                  prefixText:
                      'pages.dashboard.control.multipl_card.press_adv'.tr(),
                  onChange:
                      model.klippyCanReceiveCommands && !model.multipliersLocked
                          ? model.onEditedPressureAdvanced
                          : null,
                  numberFormat: NumberFormat('0.##### mm/s'),
                  unit: 'mm/s',
                ),
                _SliderOrTextInput(
                  initialValue: model.smoothTime,
                  prefixText:
                      'pages.dashboard.control.multipl_card.smooth_time'.tr(),
                  onChange:
                      model.klippyCanReceiveCommands && !model.multipliersLocked
                          ? model.onEditedSmoothTime
                          : null,
                  numberFormat: NumberFormat('0.### s'),
                  maxValue: 0.2,
                  unit: 's',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LimitsCard extends ViewModelWidget<ControlTabViewModel> {
  const LimitsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ControlTabViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.tune),
            title: Text('pages.dashboard.control.limit_card.title').tr(),
            trailing: IconButton(
                onPressed: model.onToggleLimitLock,
                icon: AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: model.limitsLocked
                      ? Icon(FlutterIcons.lock_faw, key: const ValueKey('lock'))
                      : Icon(FlutterIcons.unlock_faw,
                          key: const ValueKey('unlock')),
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              children: [
                _SliderOrTextInput(
                  initialValue: model.maxVelocity,
                  prefixText: tr('pages.dashboard.control.limit_card.velocity'),
                  onChange:
                      model.klippyCanReceiveCommands && !model.limitsLocked
                          ? model.onEditedMaxVelocity
                          : null,
                  numberFormat: NumberFormat('0 mm/s'),
                  unit: 'mm/s',
                  maxValue: 500,
                ),
                _SliderOrTextInput(
                  initialValue: model.maxAccel,
                  prefixText: tr('pages.dashboard.control.limit_card.accel'),
                  onChange:
                      model.klippyCanReceiveCommands && !model.limitsLocked
                          ? model.onEditedMaxAccel
                          : null,
                  numberFormat: NumberFormat('0 mm/s²'),
                  unit: 'mm/s²',
                  maxValue: 5000,
                ),
                _SliderOrTextInput(
                  initialValue: model.squareCornerVelocity,
                  prefixText:
                      tr('pages.dashboard.control.limit_card.sq_corn_vel'),
                  onChange:
                      model.klippyCanReceiveCommands && !model.limitsLocked
                          ? model.onEditedMaxSquareCornerVelocity
                          : null,
                  numberFormat: NumberFormat('0.# mm/s'),
                  unit: 'mm/s',
                  maxValue: 8,
                ),
                _SliderOrTextInput(
                  initialValue: model.maxAccelToDecel,
                  prefixText:
                      tr('pages.dashboard.control.limit_card.accel_to_decel'),
                  onChange:
                      model.klippyCanReceiveCommands && !model.limitsLocked
                          ? model.onEditedMaxAccelToDecel
                          : null,
                  numberFormat: NumberFormat('0 mm/s²'),
                  unit: 'mm/s²',
                  maxValue: 3500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderOrTextInput extends HookWidget {
  final ValueChanged<double>? onChange;
  final String prefixText;
  final double initialValue;
  final NumberFormat? numberFormat;
  final double maxValue;
  final double minValue;
  final String? unit;

  const _SliderOrTextInput(
      {Key? key,
      required this.initialValue,
      required this.prefixText,
      required this.onChange,
      this.numberFormat,
      this.maxValue = 2,
      this.minValue = 0,
      this.unit})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var initial = useState(initialValue);
    var sliderPos = useState(initial.value);
    var fadeState = useState(CrossFadeState.showFirst);
    var textEditingController = useTextEditingController(text: '0');
    var focusText = useFocusNode();
    var focusRequested = useState(false);
    var inputValid = useState(true);

    NumberFormat numFormat = numberFormat ?? NumberFormat('###%');

    if (initial.value != initialValue) {
      initial.value = initialValue;
      sliderPos.value = initialValue;
      textEditingController.text =
          numFormat.format(initialValue).replaceAll(RegExp(r'[^0-9.,]'), '');
    }

    if (fadeState.value == CrossFadeState.showSecond &&
        !focusRequested.value &&
        !focusText.hasFocus &&
        focusText.canRequestFocus) {
      focusRequested.value = true;
      focusText.requestFocus();
    }

    Widget suffixText = Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text(unit ?? '%'),
    );

    return Row(
      children: [
        Flexible(
          child: AnimatedCrossFade(
            firstChild: InputDecorator(
                decoration: InputDecoration(
                  label:
                      Text('$prefixText: ${numFormat.format(sliderPos.value)}'),
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
                child: Slider(
                  value: min(maxValue, sliderPos.value),
                  onChanged: onChange != null
                      ? (v) {
                          sliderPos.value = v;
                        }
                      : null,
                  onChangeEnd: onChange,
                  max: maxValue,
                  min: minValue,
                )),
            secondChild: TextField(
              enabled: onChange != null,
              onSubmitted: (String value) {
                if (!inputValid.value) return;
                double perc =
                    numFormat.parse(textEditingController.text).toDouble();
                onChange!(perc);
              },
              focusNode: focusText,
              controller: textEditingController,
              onChanged: (s) {
                if (s.isEmpty || !RegExp(r'^\d+([.,])?\d*?$').hasMatch(s)) {
                  inputValid.value = false;
                  return;
                }

                if (!inputValid.value) inputValid.value = true;
              },
              textAlign: TextAlign.end,
              keyboardType:
                  TextInputType.numberWithOptions(signed: Platform.isIOS),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
              ],
              decoration: InputDecoration(
                  prefixText: '$prefixText:',
                  border: InputBorder.none,
                  suffix: suffixText,
                  errorText: !inputValid.value
                      ? FormBuilderLocalizations.current.numericErrorText
                      : null),
            ),
            duration: kThemeAnimationDuration,
            crossFadeState: fadeState.value,
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: !inputValid.value || onChange == null
              ? null
              : () {
                  if (fadeState.value == CrossFadeState.showFirst) {
                    textEditingController.text = numFormat
                        .format(sliderPos.value)
                        .replaceAll(RegExp(r'[^0-9.,]'), '');
                    fadeState.value = CrossFadeState.showSecond;
                    focusRequested.value = false;
                  } else {
                    sliderPos.value =
                        numFormat.parse(textEditingController.text).toDouble();
                    fadeState.value = CrossFadeState.showFirst;
                    focusText.unfocus();
                  }
                },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
        )
      ],
    );
  }
}
