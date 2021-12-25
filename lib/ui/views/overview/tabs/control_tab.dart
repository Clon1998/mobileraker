import 'dart:math';

import 'package:dots_indicator/dots_indicator.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/toolhead.dart';
import 'package:mobileraker/ui/components/HorizontalScrollIndicator.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/refresh_printer.dart';
import 'package:mobileraker/ui/views/overview/tabs/control_tab_viewmodel.dart';
import 'package:stacked/stacked.dart';

class ControlTab extends ViewModelBuilderWidget<ControlTabViewModel> {
  const ControlTab({Key? key}) : super(key: key);

  @override
  Widget builder(
      BuildContext context, ControlTabViewModel model, Widget? child) {
    return PullToRefreshPrinter(
      child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              if (model.isPrinterAvailable &&
                  model.isServerAvailable &&
                  model.isMachineAvailable) ...[
                if (model.printer.gcodeMacros.isNotEmpty) GcodeMacroCard(),
                if (model.printer.print.state != PrintState.printing)
                  ExtruderControlCard(),
                FansCard(),
                if (model.printer.outputPins.isNotEmpty) PinsCard(),
              ]
            ],
          )),
    );
  }

  @override
  ControlTabViewModel viewModelBuilder(BuildContext context) =>
      ControlTabViewModel();
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
              title: Text("Fan${(model.printer.fans.length > 0) ? 's' : ''}"),
            ),
            Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var elementWidth = constraints.maxWidth / 2;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: model.fansScrollController,
                      child: Row(
                        children: buildFans(model, context, elementWidth),
                      ),
                    );
                  },
                )),
            if (model.fansSteps > 2)
              HorizontalScrollIndicator(steps: model.fansSteps, controller: model.fansScrollController, childsPerScreen: 2,)
          ],
        ),
      ),
    );
  }

  List<Widget> buildFans(
      ControlTabViewModel model, BuildContext context, width) {
    List<Widget> rows = [];

    var printFan = model.printer.printFan;
    rows.add(_FanTile(
        name: "Part Fan",
        speed: printFan.speed,
        width: width,
        onTap: model.canUsePrinter ? model.onEditPartFan : null));

    for (NamedFan fan in model.printer.fans) {
      VoidCallback? f;
      if (fan is GenericFan) f = () => model.onEditGenericFan(fan);
      var row = _FanTile(
        name: model.beautifyName(fan.name),
        speed: fan.speed,
        width: width,
        onTap: model.canUsePrinter ? f : null,
      );
      rows.add(row);
    }

    return rows;
  }
}

class _FanTile extends StatelessWidget {
  final String name;
  final double speed;
  final double width;
  final VoidCallback? onTap;

  const _FanTile({
    Key? key,
    required this.name,
    required this.speed,
    required this.width,
    this.onTap,
  }) : super(key: key);

  String get fanSpeed {
    double fanPerc = speed * 100;
    if (speed > 0) return '${fanPerc.toStringAsFixed(0)} %';
    return 'Off';
  }

  @override
  Widget build(BuildContext context) {
    var col = Theme.of(context).primaryColorLight;

    double icoSize = 30;
    var w = speed > 0
        ? SpinningFan(size: icoSize)
        : Icon(
            FlutterIcons.fan_off_mco,
            size: icoSize,
          );

    return CardWithButton(
        width: width,
        backgroundColor: col,
        child: Row(
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
        ),
        buttonChild: onTap == null ? const Text('Fan') : const Text('Set'),
        onTap: onTap);
  }
}

class SpinningFan extends StatefulWidget {
  final double? size;

  SpinningFan({this.size});

  @override
  _SpinningFanState createState() => _SpinningFanState();
}

class _SpinningFanState extends State<SpinningFan>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  _SpinningFanState() {
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Icon(FlutterIcons.fan_mco, size: widget.size),
    );
  }
}

class ExtruderControlCard extends ViewModelWidget<ControlTabViewModel> {
  const ExtruderControlCard({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, ControlTabViewModel model) {
    Color textBtnColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
            title: Text('Extruder'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              children: <Widget>[
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: TextButton.icon(
                        onPressed:
                            model.canUsePrinter ? model.onDeRetractBtn : null,
                        icon: Icon(FlutterIcons.plus_ant),
                        label: Text("Extrude"),
                        style: TextButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5.0))),
                            primary: textBtnColor),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: TextButton.icon(
                        onPressed:
                            model.canUsePrinter ? model.onRetractBtn : null,
                        icon: Icon(FlutterIcons.minus_ant),
                        label: Text("Retract"),
                        style: TextButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5.0))),
                            primary: textBtnColor),
                      ),
                    ),
                  ],
                ),
                Spacer(flex: 1),
                Column(
                  children: [
                    Text("Extrude length [mm]"),
                    RangeSelector(
                        selectedIndex: model.selectedIndexRetractLength,
                        onSelected: model.onSelectedRetractChanged,
                        values: model.retractLengths
                            .map((e) => e.toString())
                            .toList())
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String homedChipTitle(Set<PrinterAxis> homedAxes) {
    if (homedAxes.isEmpty)
      return 'NONE';
    else {
      List<PrinterAxis> l = homedAxes.toList();
      l.sort((a, b) => a.index.compareTo(b.index));
      return l.map((e) => EnumToString.convertToString(e)).join();
    }
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
            title: Text('Gcode-Macros'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Wrap(
              spacing: 5.0,
              children: _generateGCodeChips(context, model),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _generateGCodeChips(
      BuildContext context, ControlTabViewModel model) {
    var themeData = Theme.of(context);
    var bgCol = themeData.brightness == Brightness.dark
        ? themeData.colorScheme.secondary
        : themeData.primaryColor;
    return List<Widget>.generate(
      model.printer.gcodeMacros.length,
      (int index) {
        String macro = model.printer.gcodeMacros[index];

        return ActionChip(
          label: Text(macro.replaceAll("_", " ")),
          backgroundColor: bgCol,
          onPressed: () => model.onMacroPressed(index),
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
              title: Text(
                  "Output Pin${(model.printer.outputPins.length > 0) ? 's' : ''}"),
            ),
            Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var elementWidth = constraints.maxWidth / 2;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: model.outputsScrollController,
                      child: Row(
                        children: buildPins(model, context, elementWidth),
                      ),
                    );
                  },
                )),
            if (model.outputSteps > 2)
              HorizontalScrollIndicator(steps: model.outputSteps, childsPerScreen: 2, controller: model.outputsScrollController)
          ],
        ),
      ),
    );
  }

  List<Widget> buildPins(
      ControlTabViewModel model, BuildContext context, double width) {
    List<Widget> rows = [];

    for (var pin in model.printer.outputPins) {
      var configForOutput = model.configForOutput(pin.name);
      var row = _PinTile(
        name: model.beautifyName(pin.name),
        value: pin.value * (configForOutput?.scale ?? 1),
        width: width,
        onTap: model.canUsePrinter
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
  final double width;
  final VoidCallback? onTap;

  const _PinTile({
    Key? key,
    required this.name,
    required this.value,
    required this.width,
    this.onTap,
  }) : super(key: key);

  String get pinValue {
    // double perc = value * 100;
    if (value == value.round()) return value.toStringAsFixed(0);
    if (value > 0) return value.toStringAsFixed(2);
    return 'Off';
  }

  @override
  Widget build(BuildContext context) {
    var col = Theme.of(context).primaryColorLight;

    return CardWithButton(
        width: width,
        backgroundColor: col,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.caption),
            Text(pinValue, style: Theme.of(context).textTheme.headline6),
          ],
        ),
        buttonChild: onTap == null ? const Text('Pin') : const Text('Set'),
        onTap: onTap);
  }
}
