import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/model/moonraker/gcode_macro.dart';
import 'package:mobileraker/data/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/ui/components/HorizontalScrollIndicator.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/refresh_printer.dart';
import 'package:mobileraker/ui/views/dashboard/tabs/control_tab_viewmodel.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

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
          if (model.printer.print.state != PrintState.printing)
            ExtruderControlCard(),
          MultipliersCard(),
          FansCard(),
          if (model.printer.outputPins.isNotEmpty) PinsCard(),
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
                  .plural(model.printer.fans.length),
            ),
            Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var elementWidth = constraints.maxWidth / 2;
                    return SingleChildScrollView(
                      key: PageStorageKey<String>('fanscroll'),
                      scrollDirection: Axis.horizontal,
                      controller: model.fansScrollController,
                      child: Row(
                        children: buildFans(model, context, elementWidth),
                      ),
                    );
                  },
                )),
            if (model.fansSteps > 2)
              HorizontalScrollIndicator(
                steps: model.fansSteps,
                controller: model.fansScrollController,
                childsPerScreen: 2,
              )
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
        name: 'pages.dashboard.control.fan_card.part_fan'.tr(),
        speed: printFan.speed,
        width: width,
        onTap: model.canUsePrinter ? model.onEditPartFan : null));

    for (NamedFan fan in model.filteredFans) {
      VoidCallback? f;
      if (fan is GenericFan) f = () => model.onEditGenericFan(fan);
      var row = _FanTile(
        name: beautifyName(fan.name),
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
        width: width,
        child: Builder(
          builder: (context) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: Theme.of(context).textTheme.caption),
                    Text(fanSpeed,
                        style: Theme.of(context).textTheme.headline6),
                  ],
                ),
                w,
              ],
            );
          }
        ),
        buttonChild: onTap == null
            ? const Text('pages.dashboard.control.fan_card.static_fan_btn').tr()
            : const Text('general.set').tr(),
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
  late AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  )..repeat();
  late Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.linear,
  );

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Icon(FlutterIcons.fan_mco, size: widget.size),
    );
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
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
            title: Text('pages.dashboard.control.extrude_card.title').tr(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              children: <Widget>[
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed:
                            model.canUsePrinter ? model.onDeRetractBtn : null,
                        icon: Icon(FlutterIcons.plus_ant),
                        label:
                            Text('pages.dashboard.control.extrude_card.extrude')
                                .tr(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed:
                            model.canUsePrinter ? model.onRetractBtn : null,
                        icon: Icon(FlutterIcons.minus_ant),
                        label:
                            Text('pages.dashboard.control.extrude_card.retract')
                                .tr(),
                      ),
                    ),
                  ],
                ),
                Spacer(flex: 1),
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
                    onChanged: model.onMacroGroupSelected,
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
        bool disabled = (!model.canUsePrinter ||
            (model.isPrinting && !macro.showWhilePrinting));
        return Visibility(
          visible:
              model.printer.gcodeMacros.contains(macro.name) && macro.visible,
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
                  model.printer.outputPins.length)),
            ),
            Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var elementWidth = constraints.maxWidth / 2;
                    return SingleChildScrollView(
                      key: PageStorageKey<String>('outputScroll'),
                      scrollDirection: Axis.horizontal,
                      controller: model.outputsScrollController,
                      child: Row(
                        children: buildPins(model, context, elementWidth),
                      ),
                    );
                  },
                )),
            if (model.outputSteps > 2)
              HorizontalScrollIndicator(
                  steps: model.outputSteps,
                  childsPerScreen: 2,
                  controller: model.outputsScrollController)
          ],
        ),
      ),
    );
  }

  List<Widget> buildPins(
      ControlTabViewModel model, BuildContext context, double width) {
    List<Widget> rows = [];

    for (var pin in model.filteredPins) {
      var configForOutput = model.configForOutput(pin.name);
      var row = _PinTile(
        name: beautifyName(pin.name),
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
    return 'general.off'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        width: width,
        child: Builder(
          builder: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: Theme.of(context).textTheme.caption),
                Text(pinValue,
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            );
          }
        ),
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                ElevatedButton(
                  onPressed:
                      model.canUsePrinter ? model.onEditSpeedMultiplier : null,
                  child: Text(
                      '${tr('pages.dashboard.general.print_card.speed')}: ${model.speedMultiplier}%'),
                ),
                ElevatedButton(
                  onPressed:
                      model.canUsePrinter ? model.onEditFlowMultiplier : null,
                  child: Text(
                      '${tr('pages.dashboard.control.multipl_card.flow')}: ${model.flowMultiplier}%'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
