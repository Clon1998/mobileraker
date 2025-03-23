/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/dashboard_card.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class DashboardCardsBottomSheet extends HookWidget {
  const DashboardCardsBottomSheet({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.maybeSizeOf(context)?.width ?? 100;

    var availableCards = DashboardComponentType.values;

    return ProviderScope(
      child: Builder(builder: (context) {
        var themeData = Theme.of(context);

        var cssGrid = AlignedGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
          itemCount: availableCards.length,
          itemBuilder: (ictx, index) {
            var e = availableCards[index];

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(context, e),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: FittedBox(
                  key: Key(e.name),
                  child: SizedBox(
                    width: width,
                    child: AbsorbPointer(
                      child: DasboardCard.preview(
                        type: e,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

        final title = PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                visualDensity: VisualDensity.compact,
                titleAlignment: ListTileTitleAlignment.center,
                title: Text(
                  'bottom_sheets.dashboard_cards.title',
                  style: themeData.textTheme.headlineSmall,
                ).tr(),
                subtitle: Text(
                  'bottom_sheets.dashboard_cards.subtitle',
                  style: themeData.textTheme.bodySmall,
                ).tr(),
              ),
              const Divider(height: 0),
            ],
          ),
        );

        return SheetContentScaffold(
          appBar: title,
          body: cssGrid,
        );
      }),
    );
  }

  void onSelect(BuildContext context, DashboardComponentType type) {
    talker.info('Selected $type');
    context.pop(BottomSheetResult.confirmed(type));
  }
}
