/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/bed_mesh/bed_mesh_profile.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';

import 'non_printing_sheet.dart';

class BedMeshSettingsBottomSheet extends HookWidget {
  const BedMeshSettingsBottomSheet({super.key, required this.arguments});

  final BedMeshSettingsBottomSheetArguments arguments;

  @override
  Widget build(BuildContext context) {
    var numberFormat = NumberFormat('0.000mm', context.locale.toStringWithSeparator());

    var activeProfileState = useState(arguments.activeProfile);

    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.8,
      minChildSize: 0.35,
      builder: (ctx, scrollController) {
        var themeData = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min, // To make the card compact
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'bottom_sheets.bedMesh.load_bed_mesh_profile',
                              style: themeData.textTheme.headlineSmall,
                            ).tr(),
                            Text(
                              arguments.activeProfile != null
                                  ? tr('bottom_sheets.bedMesh.currently_active',
                                      args: [arguments.activeProfile.toString()])
                                  : tr('bottom_sheets.bedMesh.no_profile_active'),
                              textAlign: TextAlign.center,
                              style: themeData.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListView(
                            controller: scrollController,
                            children: [
                              ListTile(
                                title: const Text('bottom_sheets.bedMesh.no_mesh',
                                        maxLines: 1, overflow: TextOverflow.ellipsis)
                                    .tr(),
                                subtitle: const Text('bottom_sheets.bedMesh.clear_loaded_profile').tr(),
                                selected: activeProfileState.value == null,
                                selectedColor: themeData.colorScheme.onSurfaceVariant,
                                selectedTileColor: themeData.colorScheme.surfaceVariant,
                                onTap: () {
                                  activeProfileState.value = null;
                                },
                              ),
                              for (var profile in arguments.profiles)
                                ListTile(
                                  // leading: profile.name == arguments.activeProfile? const Icon(Icons.chevron_right_outlined) : null,
                                  selected: profile.name == activeProfileState.value,
                                  selectedColor: themeData.colorScheme.onSurfaceVariant,
                                  selectedTileColor: themeData.colorScheme.surfaceVariant,
                                  // dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(
                                    profile.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text('${profile.meshParams.xCount}x${profile.meshParams.yCount} Mesh'),
                                  // subtitle: Text('Range: ${numberFormat.format(profile.valueRange)}'),
                                  trailing: Tooltip(
                                    message: tr('pages.dashboard.control.bed_mesh_card.range_tooltip'),
                                    child: Chip(
                                      backgroundColor: profile.name == activeProfileState.value
                                          ? themeData.colorScheme.primaryContainer
                                          : null,
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        numberFormat.format(profile.valueRange),
                                        style: TextStyle(
                                          color: profile.name == activeProfileState.value
                                              ? themeData.colorScheme.onPrimaryContainer
                                              : null,
                                        ),
                                      ),
                                      avatar: const Icon(
                                        FlutterIcons.unfold_less_horizontal_mco,
                                        // FlutterIcons.flow_line_ent,
                                        // color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    activeProfileState.value = profile.name;
                                    // Navigator.of(context).pop(profile);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ...List.generate(otherGrps.length, (index) {
                      //   var grp = otherGrps.elementAtOrNull(index)!;
                      //   return _MacroGroup(
                      //     macroGroup: grp,
                      //     controllerProvider: controllerProvider,
                      //   );
                      // }),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FullWidthButton(
                    onPressed: () {
                      Navigator.of(context).pop(BottomSheetResult.confirmed(activeProfileState.value));
                    },
                    child: const Text('general.activate').tr(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BedMeshSettingsBottomSheetArguments {
  const BedMeshSettingsBottomSheetArguments(this.activeProfile, this.profiles);

  final String? activeProfile;
  final List<BedMeshProfile> profiles;
}
