/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';

class SupporterBenefits extends ConsumerWidget {
  const SupporterBenefits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final goRouter = ref.read(goRouterProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: themeData.disabledColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0) - const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(FlutterIcons.gift_outline_mco, size: 20, color: themeData.colorScheme.primary),
                const Gap(8),
                Text(
                  'pages.paywall.benefits.title',
                  style: themeData.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ).tr(),
              ],
            ),
            Gap(16),
            _BenefitGrid(),
            Center(
              child: TextButton.icon(
                onPressed: () => goRouter.pushNamed(AppRoute.supportDev_benefits.name),
                label: const Text('pages.paywall.benefits.discover_all').tr(),
                icon: const Icon(Icons.keyboard_arrow_right),
                iconAlignment: IconAlignment.end,
                style: TextButton.styleFrom(
                  textStyle: themeData.textTheme.bodySmall,
                  iconSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildFeatureItem(
                context,
                Icons.space_dashboard_outlined,
                'pages.paywall.benefits.custom_dashboard_perk.title',
                'pages.paywall.benefits.custom_dashboard_perk.short',
              ),
            ),
            Expanded(
              child: _buildFeatureItem(
                context,
                FlutterIcons.printer_3d_nozzle_outline_mco,
                'pages.paywall.benefits.unlimited_printers_perk.title',
                'pages.paywall.benefits.unlimited_printers_perk.short',
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildFeatureItem(
                context,
                Icons.shield_outlined,
                'pages.paywall.benefits.ad_free_perk.title',
                'pages.paywall.benefits.ad_free_perk.short',
              ),
            ),
            Expanded(
              child: _buildFeatureItem(
                context,
                Icons.design_services_outlined,
                'pages.paywall.benefits.advanced_perk.title',
                'pages.paywall.benefits.advanced_perk.short',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    var themeData = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: themeData.colorScheme.primary),
        const SizedBox(height: 4, width: double.infinity),
        Text(title, style: themeData.textTheme.titleSmall).tr(),
        Text(description, style: themeData.textTheme.bodySmall).tr(),
      ],
    );
  }
}
