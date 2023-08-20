/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/routing/app_router.dart';

class SupporterOnlyFeature extends StatelessWidget {
  const SupporterOnlyFeature({
    Key? key,
    required this.text,
  }) : super(key: key);

  final Widget text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          FlutterIcons.hand_holding_heart_faw5s,
          size: 32,
        ),
        SizedBox(
          height: 8,
        ),
        DefaultTextStyle(
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!,
            child: text),
        TextButton(
            onPressed: () {
              context.pushNamed(AppRoute.supportDev.name);
            },
            child: const Text('components.supporter_only_feature.button').tr())
      ],
    );
  }
}
