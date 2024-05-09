/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SupporterOnlyDialog extends StatelessWidget {
  const SupporterOnlyDialog({
    super.key,
    required this.request,
    required this.completer,
  });
  final DialogRequest request;
  final Function(DialogResponse) completer;

  @override
  Widget build(BuildContext context) {
    return MobilerakerDialog(
      padding: const EdgeInsets.only(top: 12.0, bottom: 6, left: 8, right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: <Widget>[
          Text(
            'components.supporter_only_feature.dialog_title',
            style: Theme.of(context).textTheme.headlineSmall,
          ).tr(),
          const SizedBox(height: 16.0),
          SupporterOnlyFeature(text: Text(request.body!)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => completer(DialogResponse()),
                child: Text(
                  MaterialLocalizations.of(context).closeButtonLabel,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
