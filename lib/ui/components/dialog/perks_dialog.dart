/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';

class PerksDialog extends StatelessWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const PerksDialog({Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 6, left: 8, right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the card compact
          children: <Widget>[
            Text(
              'dialogs.supporter_perks.title',
              style: Theme.of(context).textTheme.headlineSmall,
            ).tr(),
            Text(
              'dialogs.supporter_perks.body',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.justify,
            ).tr(),
            const SizedBox(
              height: 8,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text(
                            'dialogs.supporter_perks.notification_perk.title')
                        .tr(),
                    subtitle: const Text(
                            'dialogs.supporter_perks.notification_perk.subtitle')
                        .tr(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  ListTile(
                    title:
                        const Text('dialogs.supporter_perks.webrtc_perk.title')
                            .tr(),
                    subtitle: const Text(
                            'dialogs.supporter_perks.webrtc_perk.subtitle')
                        .tr(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  ListTile(
                    title:
                        const Text('dialogs.supporter_perks.theme_perk.title')
                            .tr(),
                    subtitle: const Text(
                            'dialogs.supporter_perks.theme_perk.subtitle')
                        .tr(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  ListTile(
                    title:
                        const Text('dialogs.supporter_perks.contact_perk.title')
                            .tr(),
                    subtitle: const Text(
                            'dialogs.supporter_perks.contact_perk.subtitle')
                        .tr(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
            ),
            const Divider(),
            Text(
              "dialogs.supporter_perks.hint",
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
            ).tr(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => completer(DialogResponse()),
                  child:
                      Text(MaterialLocalizations.of(context).closeButtonLabel),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
