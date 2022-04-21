import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

enum BottomSheetType {
  ManagementMenu,
}

setupBottomSheetUi() {
  final bottomSheetService = locator<BottomSheetService>();

  final builders = {
    BottomSheetType.ManagementMenu: (context, sheetRequest, completer) =>
        _NonPrintingBottomSheet(request: sheetRequest, completer: completer)
  };

  bottomSheetService.setCustomSheetBuilders(builders);
}

class _NonPrintingBottomSheet
    extends ViewModelBuilderWidget<NonPrintingBottomSheetViewModel> {
  final SheetRequest request;
  final Function(SheetResponse) completer;

  const _NonPrintingBottomSheet({
    Key? key,
    required this.request,
    required this.completer,
  }) : super(key: key);

  @override
  Widget builder(BuildContext context, NonPrintingBottomSheetViewModel model,
      Widget? child) {
    var themeData = Theme.of(context);
    var buttonStyle = ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
        ));

    return Container(
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 10),
      decoration: BoxDecoration(
        color: themeData.bottomSheetTheme.modalBackgroundColor,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15), topRight: Radius.circular(15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: model.onShutdownHostPressed,
                      child: Text('general.shutdown').tr(),
                      style: buttonStyle,
                    ),
                  )),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  FlutterIcons.raspberry_pi_faw5d,
                  color: themeData.colorScheme.onBackground,
                ),
              ),
              Flexible(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: model.onRestartHostPressed,
                      child: Text('general.restart').tr(),
                      style: buttonStyle,
                    ),
                  ))
            ],
          ),
          SizedBox(
            height: 5,
          ),
          FullWidthButton(
              child: Text('Klipper ${tr('general.restart').toLowerCase()}'),
              onPressed: model.onRestartKlipperPressed,
              buttonStyle: buttonStyle),
          FullWidthButton(
              child: Text('Moonraker ${tr('general.restart').toLowerCase()}'),
              onPressed: model.onRestartMoonrakerPressed,
              buttonStyle: buttonStyle),
          FullWidthButton(
              child: Text('${tr('general.firmware')} ${tr('general.restart').toLowerCase()}'),
              onPressed: model.onRestartMCUPressed,
              buttonStyle: buttonStyle),
          ElevatedButton.icon(
            label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
            icon: Icon(Icons.keyboard_arrow_down),
            onPressed: model.onClosePressed,
            style: buttonStyle,
          )
        ],
      ),
    );
  }

  @override
  NonPrintingBottomSheetViewModel viewModelBuilder(BuildContext context) =>
      NonPrintingBottomSheetViewModel(request, completer);
}

class FullWidthButton extends StatelessWidget {
  final VoidCallback onPressed;

  final Widget child;

  final ButtonStyle? buttonStyle;

  const FullWidthButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.buttonStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: child,
          style: buttonStyle,
        ));
  }
}

class NonPrintingBottomSheetViewModel extends BaseViewModel {
  final SheetRequest request;
  final Function(SheetResponse) completer;

  final _snackBarService = locator<SnackbarService>();
  final _selectedMachineService = locator<SelectedMachineService>();

  NonPrintingBottomSheetViewModel(this.request, this.completer);

  KlippyService? get _klippyService {
    return _selectedMachineService.selectedMachine.valueOrNull?.klippyService;
  }

  onClosePressed() {
    completer(SheetResponse());
  }

  onRestartMoonrakerPressed() {
    _klippyService?.restartMoonraker();
    completer(SheetResponse());
  }

  onRestartKlipperPressed() {
    _klippyService?.restartKlipper();
    completer(SheetResponse());
  }

  onRestartMCUPressed() {
    _klippyService?.restartMCUs();
    completer(SheetResponse());
  }

  onRestartHostPressed() {
    _klippyService?.rebootHost();
    completer(SheetResponse());
  }

  onShutdownHostPressed() {
    _klippyService?.shutdownHost();
    completer(SheetResponse());
  }
}
