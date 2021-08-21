import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/ui/components/CardWithButton.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/refreshPrinter.dart';
import 'package:mobileraker/ui/views/overview/tabs/control_tab_viewmodel.dart';
import 'package:stacked/stacked.dart';

class ControlTab extends ViewModelBuilderWidget<ControlTabViewModel> {
  const ControlTab({Key? key}) : super(key: key);

  @override
  Widget builder(
      BuildContext context, ControlTabViewModel model, Widget? child) {
    return PullToRefreshPrinter(
      child: ListView(
        padding: EdgeInsets.only(bottom: 20),
        children: [
          if (model.hasPrinter &&
              model.hasServer &&
              model.isPrinterSelected) ...[
            GcodeMacroCard(),
            if (model.printer.print.state != PrintState.printing)
              ExtruderControlCard(),
            FansCard(),
            PinsCard(),
          ]
        ],
      ),
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
              padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  var elementWidth = constraints.maxWidth / 2;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: buildFans(model, context, elementWidth),
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }

  List<Widget> buildFans(
      ControlTabViewModel model, BuildContext context, width) {
    List<Widget> rows = [];

    var printFan = model.printer.printFan;
    rows.add(_FanTile(
        name: "Part Cooling",
        speed: printFan.speed,
        width: width,
        onTap: model.onEditPartFan));

    for (NamedFan fan in model.printer.fans) {
      VoidCallback? f;
      if (fan is GenericFan) f = () => model.onEditGenericFan(fan);
      var row = _FanTile(
        name: model.beautifyName(fan.name),
        speed: fan.speed,
        width: width,
        onTap: f,
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
                      margin: EdgeInsets.all(5),
                      child: TextButton.icon(
                        onPressed: model.onDeRetractBtn,
                        icon: Icon(FlutterIcons.plus_ant),
                        label: Text("Extrude"),
                        style: TextButton.styleFrom(
                            backgroundColor: Theme.of(context).accentColor,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5.0))),
                            primary: textBtnColor),
                      ),
                      color: Theme.of(context).accentColor,
                    ),
                    Container(
                      margin: EdgeInsets.all(5),
                      child: TextButton.icon(
                        onPressed: model.onRetractBtn,
                        icon: Icon(FlutterIcons.minus_ant),
                        label: Text("Retract"),
                        style: TextButton.styleFrom(
                            backgroundColor: Theme.of(context).accentColor,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5.0))),
                            primary: textBtnColor),
                      ),
                      color: Theme.of(context).accentColor,
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
        ? themeData.accentColor
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
              padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  var elementWidth = constraints.maxWidth / 2;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: buildPins(model, context, elementWidth),
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }

  List<Widget> buildPins(
      ControlTabViewModel model, BuildContext context, double width) {
    List<Widget> rows = [];

    for (var pin in model.printer.outputPins) {
      var row = _PinTile(
        name: model.beautifyName(pin.name),
        value: pin.value,
        width: width,
        onTap: () => model.onEditPin(pin),
      );
      rows.add(row);
    }
    return rows;
  }
}

class _PinTile extends StatelessWidget {
  final String name;
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
    double perc = value * 100;
    if (value > 0) return '${perc.toStringAsFixed(0)} %';
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
