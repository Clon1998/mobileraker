/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:purchases_flutter/models/package_wrapper.dart';

class TippingDialog extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const TippingDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  List<Package> get tipPackages => request.data;

  @override
  Widget build(BuildContext context) {
    var selected = useState(tipPackages.skip(1).first);

    return MobilerakerDialog(
      actionText: tr('dialogs.tipping.tip'),
      onAction: () => completer(DialogResponse.confirmed(selected.value)),
      dismissText: MaterialLocalizations.of(context).closeButtonLabel,
      onDismiss: () => completer(DialogResponse()),
      child: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'dialogs.tipping.title',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ).tr(),
              const SizedBox(height: 10),
              FormBuilderDropdown(
                name: 'tipAmnt',
                initialValue: selected.value,
                decoration: InputDecoration(
                  labelStyle: Theme.of(context).textTheme.labelLarge,
                  labelText: tr('dialogs.tipping.amount_label'),
                ),
                items: tipPackages
                    .map((e) => DropdownMenuItem<Package>(
                          value: e,
                          child: Text(e.storeProduct.priceString),
                        ))
                    .toList(),
                onChanged: (v) => selected.value = v!,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: FormBuilderValidators.compose(
                  [FormBuilderValidators.required()],
                ),
              ),
              Text(
                'dialogs.tipping.body',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ).tr(),
            ],
          ),
        ],
      ),
    );
  }
}
