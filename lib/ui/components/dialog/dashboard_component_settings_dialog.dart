/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class DashboardComponentSettingsDialog extends HookWidget {
  const DashboardComponentSettingsDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  final DialogRequest request;
  final Function(DialogResponse) completer;

  @override
  Widget build(BuildContext context) {
    final DashboardComponent component = request.data as DashboardComponent;

    final showBeforeReady = useState(component.showBeforePrinterReady);
    final showWhilePrinting = useState(component.showWhilePrinting);

    onDone() {
      completer(DialogResponse.confirmed((showWhilePrinting.value, showBeforeReady.value)));
    }

    return MobilerakerDialog(
      actionText: tr('general.confirm'),
      onAction: onDone,
      dismissText: tr('general.cancel'),
      onDismiss: () => completer(DialogResponse.aborted()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Settings for ${component.type.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          InputDecorator(
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            child: SwitchListTile(
              value: showWhilePrinting.value,
              title: Text('Show while printing:'),
              subtitle: Text('Show the component while the printer is printing.'),
              onChanged: (value) => showWhilePrinting.value = value,
            ),
          ),
          InputDecorator(
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            child: SwitchListTile(
              value: showBeforeReady.value,
              title: Text('Show before printer ready:'),
              subtitle: Text('Show the component before the printer is ready.'),
              onChanged: (value) => showBeforeReady.value = value,
            ),
          ),
        ],
      ),
    );
  }
}
