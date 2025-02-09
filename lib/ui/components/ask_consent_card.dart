/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/enums/consent_status.dart';
import 'package:common/data/model/firestore/consent_entry.dart';
import 'package:common/service/consent_service.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AskConsentCard extends ConsumerWidget {
  const AskConsentCard({super.key, required this.type});

  //TODO: This is far from being perfect in regards to the type. The text wont use the type for now...
  final ConsentEntryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentState = ref.watch(consentEntryProvider(type));
    var consentService = ref.watch(consentServiceProvider);

    return AnimatedSizeAndFade(
      child: switch (consentState) {
        AsyncData(value: ConsentEntry(status: ConsentStatus.UNKNOWN)) => _ConsentCard(
            key: Key('consent_card-$type'),
            onAccept: () => consentService.updateConsentEntry(type, ConsentStatus.GRANTED),
            onDecline: () => consentService.updateConsentEntry(type, ConsentStatus.DENIED),
          ),
        _ => SizedBox.shrink(),
      },
    );
  }
}

class _ConsentCard extends HookWidget {
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _ConsentCard({
    super.key,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    var submitted = useState(false);

    final themeData = Theme.of(context);
    final textStyle = themeData.useMaterial3
        ? themeData.textTheme.bodyMedium
        : themeData.textTheme.bodyMedium?.copyWith(
            color: themeData.textTheme.bodySmall?.color,
          );
    final subtleTextStyle = TextStyle(
      color: textStyle?.color?.darken(10),
      fontSize: 11,
    );
    final disclaimerTextStyle = TextStyle(
      color: textStyle?.color?.darken(10),
      fontSize: 10,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.policy_outlined),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'consent_cards.marketing_notifications.title',
                    style: themeData.useMaterial3 ? themeData.textTheme.bodyLarge : themeData.textTheme.titleMedium,
                  ).tr(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DefaultTextStyle.merge(
              style: textStyle,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('consent_cards.marketing_notifications.description').tr(),
                  const SizedBox(height: 16),
                  Text(
                    'consent_cards.marketing_notifications.agreement',
                    style: subtleTextStyle.copyWith(fontSize: textStyle?.fontSize),
                  ).tr(),
                  const SizedBox(height: 10),
                  Text(
                    'consent_cards.marketing_notifications.terms',
                    style: subtleTextStyle,
                  ).tr(),
                  Text(
                    'consent_cards.marketing_notifications.disclaimer',
                    style: disclaimerTextStyle,
                  ).tr(),
                  OverflowBar(
                    spacing: 4,
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          submitted.value = true;
                          onDecline?.call();
                        }.unless(submitted.value || onDecline == null),
                        child: Text('general.deny').tr(),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          submitted.value = true;
                          onAccept?.call();
                        }.unless(submitted.value || onAccept == null),
                        child: Text('general.allow').tr(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
