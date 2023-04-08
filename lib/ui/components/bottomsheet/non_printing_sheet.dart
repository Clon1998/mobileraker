import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';

class NonPrintingBottomSheet extends ConsumerWidget {
  const NonPrintingBottomSheet({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var buttonStyle = ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
        ));

    var klippyService = ref.read(klipperServiceSelectedProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 10),
      decoration: BoxDecoration(
        color: themeData.bottomSheetTheme.modalBackgroundColor,
        borderRadius: const BorderRadius.only(
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
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _btnAction(context, klippyService.shutdownHost),
                      style: buttonStyle,
                      child: const Text('general.shutdown').tr(),
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
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _btnAction(context, klippyService.rebootHost),
                      style: buttonStyle,
                      child: const Text('general.restart').tr(),
                    ),
                  ))
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          FullWidthButton(
              onPressed: _btnAction(context, klippyService.restartKlipper),
              buttonStyle: buttonStyle,
              child: Text('Klipper ${tr('general.restart').toLowerCase()}')),
          FullWidthButton(
              onPressed: _btnAction(context, klippyService.restartMoonraker),
              buttonStyle: buttonStyle,
              child: Text('Moonraker ${tr('general.restart').toLowerCase()}')),
          FullWidthButton(
              onPressed: _btnAction(context, klippyService.restartMCUs),
              buttonStyle: buttonStyle,
              child: Text(
                  '${tr('general.firmware')} ${tr('general.restart').toLowerCase()}')),
          ElevatedButton.icon(
            label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.of(context).pop(),
            style: buttonStyle,
          )
        ],
      ),
    );
  }

  VoidCallback _btnAction(BuildContext ctx, VoidCallback toCall) {
    return () {
      toCall();
      Navigator.of(ctx).pop();
    };
  }
}

class FullWidthButton extends StatelessWidget {
  final VoidCallback? onPressed;

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
    return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: child,
        ));
  }
}
