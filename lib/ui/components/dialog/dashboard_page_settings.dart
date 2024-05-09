/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class DashboardPageSettings extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const DashboardPageSettings({
    super.key,
    required this.request,
    required this.completer,
  });

  DashboardTab get tab => request.data as DashboardTab;

  @override
  Widget build(BuildContext context) {
    final selectedIcon = useState(tab.icon);

    final themeData = Theme.of(context);
    return MobilerakerDialog(
      actionText: MaterialLocalizations.of(context).saveButtonLabel,
      onAction: () => completer(DialogResponse.confirmed(selectedIcon.value)),
      dismissText: MaterialLocalizations.of(context).closeButtonLabel,
      onDismiss: () => completer(DialogResponse()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Page Settings',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Select the icon for the page:',
              border: InputBorder.none,
            ),
            child: Center(
              child: Wrap(
                // alignment: WrapAlignment.spaceEvenly,
                children: [
                  for (var ico in DashboardTab.availableIcons.entries)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => selectedIcon.value = ico.key,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          ico.value,
                          color: themeData.colorScheme.primary.only(ico.key == selectedIcon.value) ??
                              themeData.colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
