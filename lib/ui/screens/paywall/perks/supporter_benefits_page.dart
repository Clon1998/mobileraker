/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/firebase/remote_config.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SupporterBenefitsPage extends StatelessWidget {
  const SupporterBenefitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Center(child: ResponsiveLimit(child: _Content()))),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    var maxNonSupporterMachines = ref.watch(remoteConfigIntProvider('non_suporters_max_printers'));
    var useAdmobs = ref.watch(remoteConfigBoolProvider('use_admobs'));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'pages.paywall.benefits.title',
                      style: themeData.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ).tr(),
                  ),
                  IconButton(
                    onPressed: context.pop,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'pages.paywall.benefits.subtitle',
                style: themeData.textTheme.titleMedium?.copyWith(
                  color: themeData.colorScheme.tertiary,
                ),
              ).tr(),
              _Tile(
                icon: Icons.space_dashboard_outlined,
                perk: 'custom_dashboard_perk',
                color: Colors.blue,
                colorForground: Colors.white,
              ),
              if (maxNonSupporterMachines >= 0)
                _Tile(
                  icon: FlutterIcons.printer_3d_nozzle_outline_mco,
                  perk: 'unlimited_printers_perk',
                  color: Colors.green,
                  colorForground: Colors.white,
                ),
              if (useAdmobs)
                _Tile(
                  icon: Icons.shield_outlined,
                  perk: 'ad_free_perk',
                  color: Colors.red,
                  colorForground: Colors.white,
                ),
              _Tile(
                icon: Icons.notifications_outlined,
                perk: 'notification_perk',
                color: Colors.amber,
                colorForground: Colors.white,
              ),
              _Tile(
                icon: Icons.palette_outlined,
                perk: 'theme_perk',
                color: Colors.purple,
                colorForground: Colors.white,
              ),
              _Tile(
                icon: Icons.dark_mode_outlined,
                perk: 'printer_theme_perk',
                color: Colors.deepPurple,
                colorForground: Colors.white,
              ),
              _Tile(
                icon: Icons.videocam_outlined,
                perk: 'webrtc_perk',
                color: Colors.indigo,
                colorForground: Colors.white,
              ),
              _Tile(
                icon: FlutterIcons.database_ent,
                perk: 'job_queue_perk',
                color: Colors.orange,
                colorForground: Colors.white,
              ),
              _Tile(
                icon: Icons.queue_outlined,
                perk: 'spoolman_perk',
                color: Colors.teal,
                colorForground: Colors.white,
              ),
              _Tile(
                icon: Icons.folder_special_outlined,
                perk: 'full_file_management_perk',
                color: Colors.cyan,
                colorForground: Colors.white,
              ),
              _Tile(
                icon: Icons.support_agent,
                perk: 'contact_perk',
                color: Colors.pink,
                colorForground: Colors.white,
              ),
            ],
          ),
        ),
        Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: FilledButton(
            onPressed: context.pop,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: Text('pages.paywall.benefits.become_supporter').tr(),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.color,
    required this.colorForground,
    required this.perk,
  });

  final IconData icon;
  final Color color;
  final Color colorForground;
  final String perk;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 72, right: 8, bottom: 8),
        collapsedShape: RoundedRectangleBorder(
          side: BorderSide(color: themeData.disabledColor, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9.0),
            child: Icon(icon, size: 30, color: colorForground),
          ),
        ),
        title: Text('pages.paywall.benefits.$perk.title').tr(),
        subtitle: Text('pages.paywall.benefits.$perk.subtitle').tr(),
        children: [
          Divider(
            thickness: 1,
            height: 1,
          ),
          Gap(4),
          Text('pages.paywall.benefits.$perk.detail').tr(),
        ],
      ),
    );
  }
}
