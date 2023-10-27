/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';

class NonPrintingBottomSheet extends ConsumerWidget {
  const NonPrintingBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
      ),
    );

    var klippyService = ref.read(klipperServiceSelectedProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 10),
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
                    onPressed: _btnAction(context, klippyService.shutdownHost),
                    style: buttonStyle,
                    child: const Text('general.shutdown').tr(),
                  ),
                ),
              ),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FullWidthButton(
            onPressed: _btnAction(context, klippyService.restartKlipper),
            buttonStyle: buttonStyle,
            child: Text('Klipper ${tr('@.lower:general.restart')}'),
          ),
          FullWidthButton(
            onPressed: _btnAction(context, klippyService.restartMoonraker),
            buttonStyle: buttonStyle,
            child: Text('Moonraker ${tr('@.lower:general.restart')}'),
          ),
          FullWidthButton(
            onPressed: _btnAction(context, klippyService.restartMCUs),
            buttonStyle: buttonStyle,
            child: Text(
              '${tr('general.firmware')} ${tr('@.lower:general.restart')}',
            ),
          ),
          FullWidthButton(
            onPressed: _btnAction(
              context,
              () => ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.jobQueueMenu)),
            ),
            buttonStyle: buttonStyle,
            child: const Text('dialogs.supporter_perks.job_queue_perk.title').tr(),
          ),
          ElevatedButton.icon(
            label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.of(context).pop(),
            style: buttonStyle,
          ),
        ],
      ),
    );
  }

  VoidCallback _btnAction(BuildContext ctx, VoidCallback toCall) {
    return () {
      Navigator.of(ctx).pop();
      toCall();
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
      ),
    );
  }
}
