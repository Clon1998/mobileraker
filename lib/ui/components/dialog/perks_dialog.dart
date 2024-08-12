/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PerksDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const PerksDialog({super.key, required this.request, required this.completer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var maxNonSupporterMachines = ref.watch(remoteConfigIntProvider('non_suporters_max_printers'));

    return MobilerakerDialog(
      dismissText: MaterialLocalizations.of(context).closeButtonLabel,
      onDismiss: () => completer(DialogResponse.aborted()),
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
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text(
                    'dialogs.supporter_perks.custom_dashboard_perk.title',
                  ).tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.custom_dashboard_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                if (maxNonSupporterMachines >= 0)
                  ListTile(
                    title: const Text(
                      'dialogs.supporter_perks.unlimited_printers_perk.title',
                    ).tr(),
                    subtitle: const Text(
                      'dialogs.supporter_perks.unlimited_printers_perk.subtitle',
                    ).tr(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ListTile(
                  title: const Text(
                    'dialogs.supporter_perks.notification_perk.title',
                  ).tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.notification_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ListTile(
                  title: const Text('dialogs.supporter_perks.webrtc_perk.title').tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.webrtc_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ListTile(
                  title: const Text(
                    'dialogs.supporter_perks.full_file_management_perk.title',
                  ).tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.full_file_management_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ListTile(
                  title: const Text(
                    'dialogs.supporter_perks.job_queue_perk.title',
                  ).tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.job_queue_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ListTile(
                  title: const Text('dialogs.supporter_perks.theme_perk.title').tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.theme_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ListTile(
                  title: const Text(
                    'dialogs.supporter_perks.printer_theme_perk.title',
                  ).tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.printer_theme_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ListTile(
                  title: const Text('dialogs.supporter_perks.contact_perk.title').tr(),
                  subtitle: const Text(
                    'dialogs.supporter_perks.contact_perk.subtitle',
                  ).tr(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
          ),
          const Divider(),
          // Text(
          //   "dialogs.supporter_perks.hint",
          //   textAlign: TextAlign.center,
          //   style:
          //       Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
          // ).tr(),
        ],
      ),
    );
  }
}
