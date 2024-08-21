/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:url_launcher/url_launcher_string.dart';

const double baseIconSize = 20;
const basePadding = EdgeInsets.only(left: 16, right: 16);

class NavigationDrawerWidget extends HookConsumerWidget {
  const NavigationDrawerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(navWidgetControllerProvider);
    final controller = ref.watch(navWidgetControllerProvider.notifier);
    final themeData = Theme.of(context);

    final machineSelectionExt = useValueNotifier(false);

    return Drawer(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _NavHeader(machineSelectionExt),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              primary: false,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    _PrinterSelection(machineSelectionExt),
                    for (var entry in model.entries)
                      entry.isDivider
                          ? const Divider()
                          : _DrawerItem(
                              text: entry.label,
                              icon: entry.icon,
                              routeName: entry.route,
                              routeMatcher: entry.routeMatcherOrDefault,
                            ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              child: RichText(
                text: TextSpan(
                  style: themeData.textTheme.bodySmall!.copyWith(color: themeData.colorScheme.onSurface),
                  text: 'components.nav_drawer.footer'.tr(),
                  children: [
                    TextSpan(
                      text: ' GitHub ',
                      style: TextStyle(color: themeData.colorScheme.secondary),
                      children: const [
                        WidgetSpan(
                          child: Icon(FlutterIcons.github_alt_faw, size: 18),
                        ),
                      ],
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          const String url = 'https://github.com/Clon1998/mobileraker';
                          if (await canLaunchUrlString(url)) {
                            await launchUrlString(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            throw 'Could not launch $url';
                          }
                        },
                    ),
                    const TextSpan(text: '\n\n'),
                    TextSpan(
                      text: tr('pages.setting.imprint'),
                      style: TextStyle(color: themeData.colorScheme.secondary),
                      recognizer: TapGestureRecognizer()..onTap = () => controller.pushingTo('/imprint'),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  } // Note always the first is the currently selected!
}

class _NavHeader extends HookConsumerWidget {
  const _NavHeader(this.machineSelectionExt, {super.key});

  final ValueNotifier<bool> machineSelectionExt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(navWidgetControllerProvider.notifier);
    final selectedMachine = ref.watch(selectedMachineProvider);

    // UI Stuff
    final themeData = Theme.of(context);
    final themePack = ref.watch(activeThemeProvider).requireValue.themePack;
    final brandingIcon =
        (themeData.brightness == Brightness.light) ? themePack.brandingIcon : themePack.brandingIconDark;
    final background = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.primary
        : themeData.colorScheme.primaryContainer;
    final onBackground = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.onPrimary
        : themeData.colorScheme.onPrimaryContainer;

    return DrawerHeader(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.only(top: 30),
      decoration: BoxDecoration(color: background),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                if (selectedMachine.hasValue && selectedMachine.value != null) {
                  controller.pushingTo(
                    '/printer/edit',
                    arguments: selectedMachine.requireValue!,
                  );
                } else {
                  controller.pushingTo('/printer/add');
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          (brandingIcon == null)
                              ? SvgPicture.asset(
                                  'assets/vector/mr_logo.svg',
                                  width: 60,
                                  height: 60,
                                )
                              : Image(height: 60, width: 60, image: brandingIcon),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedMachine.valueOrNull?.name ?? 'Mobileraker',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: themeData.textTheme.titleLarge?.copyWith(color: onBackground),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedMachine.valueOrNull?.httpUri.host ?? 'Add printer first',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: themeData.textTheme.titleSmall?.copyWith(color: onBackground),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Tooltip(
                        message: 'components.nav_drawer.printer_settings'.tr(),
                        child: Icon(
                          FlutterIcons.settings_mdi,
                          color: onBackground,
                          size: 27,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              // contentPadding: EdgeInsets.,
              title: Text(
                'components.nav_drawer.manage_printers',
                style: TextStyle(color: onBackground),
              ).tr(),
              trailing: ValueListenableBuilder(
                valueListenable: machineSelectionExt,
                builder: (context, value, child) => AnimatedRotation(
                  duration: kThemeAnimationDuration,
                  curve: Curves.easeInOutCubic,
                  turns: value ? 0 : 0.5,
                  child: child,
                ),
                child: Icon(Icons.expand_less, color: onBackground),
              ),
              onTap: () => machineSelectionExt.value = !machineSelectionExt.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends ConsumerWidget {
  const _DrawerItem({
    required this.text,
    required this.icon,
    required this.routeName,
    required this.routeMatcher,
  });

  final String text;
  final IconData icon;
  final String routeName;
  final String routeMatcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var selectedTileColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.surfaceVariant
        : themeData.colorScheme.primaryContainer.withOpacity(.25);


    final matcher = RegExp(routeMatcher);

    return ListTile(
      selected: matcher.hasMatch(GoRouterState.of(context).uri.toString()),
      selectedTileColor: selectedTileColor,
      selectedColor: themeData.colorScheme.secondary,
      textColor: themeData.colorScheme.onSurface,
      leading: Icon(icon),
      title: Text(text),
      onTap: () => ref.read(navWidgetControllerProvider.notifier).navigateTo(routeName),
    );
  }
}

class _PrinterSelection extends HookConsumerWidget {
  const _PrinterSelection(this.machineSelectionExt, {super.key});

  final ValueNotifier<bool> machineSelectionExt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final isExpanded = useListenable(machineSelectionExt);
    final selMachine = ref.watch(selectedMachineProvider);

    return AnimatedSwitcher(
      // duration: Duration(seconds: 2),
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeOutQuad,
      switchOutCurve: Curves.easeInQuad,
      transitionBuilder: (child, anim) => SizeTransition(
        axisAlignment: 1,
        sizeFactor: anim,
        child: child,
        // child: FadeTransition(opacity: anim, child: child),
      ),
      child: (isExpanded.value)
          ? Column(
              children: [
                if (selMachine.valueOrNull != null) _MachineTile(machine: selMachine.requireValue!, isSelected: true),
                ...ref
                    .watch(allMachinesProvider.selectAs((data) => data.where(
                          (element) => element.uuid != selMachine.valueOrNull?.uuid,
                        )))
                    .maybeWhen(
                      orElse: () => [
                        ListTile(
                          title: FadingText(
                            'components.nav_drawer.fetching_printers'.tr(),
                          ),
                          contentPadding: basePadding,
                        ),
                      ],
                      data: (data) {
                        return List.generate(data.length, (index) {
                          Machine curPS = data.elementAt(index);
                          return _MachineTile(machine: curPS);
                        });
                      },
                    ),
                ListTile(
                  title: const Text('pages.printer_add.title').tr(),
                  contentPadding: basePadding,
                  textColor: themeData.colorScheme.onBackground,
                  iconColor: themeData.colorScheme.onBackground,
                  trailing: const Icon(Icons.add, size: baseIconSize),
                  onTap: () => ref.read(navWidgetControllerProvider.notifier).pushingTo('/printer/add'),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _MachineTile extends ConsumerWidget {
  const _MachineTile({
    super.key,
    required this.machine,
    this.isSelected = false,
  });

  final Machine machine;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var selectedTileColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.surfaceVariant
        : themeData.colorScheme.primaryContainer.withOpacity(.1);

    return ListTile(
      title: Text(machine.name, maxLines: 1),
      trailing: Icon(
        isSelected ? Icons.check : Icons.arrow_forward_ios_sharp,
        size: baseIconSize,
      ),
      selectedTileColor: selectedTileColor,
      selectedColor: themeData.colorScheme.secondary,
      textColor: themeData.colorScheme.onBackground,
      iconColor: themeData.colorScheme.onBackground,
      contentPadding: basePadding,
      selected: isSelected,
      onTap: isSelected
          ? null
          : () {
              Navigator.pop(context);
              ref.read(selectedMachineServiceProvider).selectMachine(machine);
            },
      onLongPress: () => ref.read(navWidgetControllerProvider.notifier).pushingTo('/printer/edit', arguments: machine),
    );
  }
}
