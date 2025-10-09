/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/payment_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:purchases_flutter/models/offering_wrapper.dart';
import 'package:purchases_flutter/models/package_wrapper.dart';

class TippingCard extends ConsumerWidget {
  const TippingCard(
      {super.key, required this.tipOffering, required this.onTipSelected, required this.onMoreTipOptionsSelected});

  final Offering tipOffering;
  final ValueChanged<Package> onTipSelected;
  final VoidCallback onMoreTipOptionsSelected;

  bool get _hasMinimumPackages => tipOffering.availablePackages.length >= 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSup = ref.watch(isSupporterProvider);

    if (!_hasMinimumPackages) {
      return const SizedBox.shrink(); // Hide widget if not enough packages
    }

    final theme = Theme.of(context);
    final packagesToHighlight = tipOffering.metadata['highlight'] as List<Object?>? ?? [];
    final packages = tipOffering.availablePackages.take(3).toList();
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color:
          isDarkMode ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.2) : theme.colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.tertiary, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onTertiaryContainer,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    FlutterIcons.coffee_outline_mco,
                    size: 20,
                    color: theme.colorScheme.tertiary,
                  ),
                  const Gap(8),
                  Text(
                    'pages.paywall.tipping.title',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).tr(),
                ],
              ),
              const Gap(8),
              Text(isSup ? 'pages.paywall.tipping.subtitle_supporter' : 'pages.paywall.tipping.subtitle',
                      style: theme.textTheme.bodySmall)
                  .tr(),
              const Gap(8),
              _buildTipOptions(packages, packagesToHighlight, theme),
              Text(
                'pages.paywall.tipping.disclaimer',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                textAlign: TextAlign.center,
              ).tr(),
              TextButton.icon(
                onPressed: onMoreTipOptionsSelected,
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  Icons.keyboard_arrow_right,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'pages.paywall.tipping.other_btn',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ).tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipOptions(
    List<Package> packages,
    List<Object?> packagesToHighlight,
    ThemeData theme,
  ) {
    final tipOptions = [
      (packages[0], '🧋', tr('products.tip.coffee')),
      (packages[1], '🥨', tr('products.tip.snack')),
      (packages[2], '🍱', tr('products.tip.lunch')),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: tipOptions.map((option) {
        final (package, emoji, label) = option;
        return Flexible(
          child: _TipOption(
            package: package,
            emoji: emoji,
            label: label,
            onTipSelected: () => onTipSelected(package),
            highlight: packagesToHighlight.contains(package.identifier),
          ),
        );
      }).toList(),
    );
  }
}

class _TipOption extends StatelessWidget {
  const _TipOption({
    required this.package,
    required this.emoji,
    required this.label,
    required this.onTipSelected,
    this.highlight = false,
  });

  final Package package;
  final String emoji;
  final String label;
  final bool highlight;
  final VoidCallback onTipSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: AspectRatio(
        aspectRatio: 1,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: highlight ? theme.colorScheme.tertiary : theme.disabledColor,
              width: highlight ? 0.75 : 0.5,
            ),
          ),
          child: InkWell(
            onTap: onTipSelected,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: theme.textTheme.titleLarge),
                  const Gap(4),
                  Text(
                    package.storeProduct.priceString,
                    style: theme.textTheme.titleSmall,
                  ),
                  const Gap(2),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
