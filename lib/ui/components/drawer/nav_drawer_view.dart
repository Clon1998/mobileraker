import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/service/ui/theme_service.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationDrawerWidget
    extends ViewModelBuilderWidget<NavDrawerViewModel> {
  final String curPath;

  NavigationDrawerWidget({required this.curPath});

  @override
  NavDrawerViewModel viewModelBuilder(BuildContext context) =>
      NavDrawerViewModel(curPath);

  @override
  Widget builder(
      BuildContext context, NavDrawerViewModel model, Widget? child) {
    var themeData = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          _NavHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _PrinterSelection(),
                  if ((model.data?.length ?? 0) > 1) ...[
                    _DrawerItem(
                      text: 'pages.overview.title'.tr(),
                      icon: FlutterIcons.view_dashboard_mco,
                      path: Routes.overViewView,
                    ),
                    Divider(),
                  ],
                  _DrawerItem(
                    text: 'pages.dashboard.title'.tr(),
                    icon: FlutterIcons.printer_3d_nozzle_mco,
                    path: Routes.dashboardView,
                  ),
                  _DrawerItem(
                    text: 'pages.console.title'.tr(),
                    icon: Icons.terminal,
                    path: Routes.consoleView,
                  ),
                  _DrawerItem(
                    text: 'pages.files.title'.tr(),
                    icon: Icons.file_present,
                    path: Routes.filesView,
                  ),
                  Divider(),
                  _DrawerItem(
                    text: 'pages.setting.title'.tr(),
                    icon: Icons.engineering_outlined,
                    path: Routes.settingView,
                  ),
                  if (kDebugMode)
                    _DrawerItem(
                      text: 'Support the Dev!',
                      icon: Icons.perm_identity,
                      path: Routes.paywallView,
                    ),
                  // Divider(color: Colors.white70),
                  // const SizedBox(height: 16),
                  // buildMenuItem(
                  //   text: 'Notifications',
                  //   icon: Icons.notifications_outlined,
                  //   onClicked: () => selectedItem(context, 5),
                  // ),
                ],
              ),
            ),
          ),
          Container(
              alignment: Alignment.center,
              padding: EdgeInsets.only(bottom: 20, top: 10),
              child: RichText(
                text: TextSpan(
                    style: themeData.textTheme.bodySmall!
                        .copyWith(color: themeData.colorScheme.onSurface),
                    text: 'components.nav_drawer.footer'.tr(),
                    children: [
                      TextSpan(
                        text: ' GitHub ',
                        style: new TextStyle(
                            color: themeData.colorScheme.secondary),
                        children: [
                          WidgetSpan(
                            child: Icon(FlutterIcons.github_alt_faw, size: 18),
                          ),
                        ],
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            const String url =
                                'https://github.com/Clon1998/mobileraker';
                            if (await canLaunch(url)) {
                              //TODO Fix this... neds Android Package Visibility
                              await launch(url);
                            } else {
                              throw 'Could not launch $url';
                            }
                          },
                      ),
                      TextSpan(text: '\n\n'),
                      TextSpan(
                        text: tr('pages.setting.imprint'),
                        style: new TextStyle(
                            color: themeData.colorScheme.secondary),
                        recognizer: TapGestureRecognizer()
                          ..onTap = model.navigateToLegal,
                      ),
                    ]),
                textAlign: TextAlign.center,
              )),
        ],
      ),
    );
  } // Note always the first is the currently selected!

// Widget buildFooter() {
//   return Row(children: [
//     TextButton(onPressed: onPressed, child: Text('Imprint'))
//   ]);
// }
}

class _NavHeader extends ViewModelWidget<NavDrawerViewModel> {
  const _NavHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, NavDrawerViewModel model) {
    var themeData = Theme.of(context);
    var brandingIcon = (themeData.brightness == Brightness.light)
        ? context.themeService.selectedThemePack.brandingIcon
        : context.themeService.selectedThemePack.brandingIconDark;
    var background = (themeData.brightness == Brightness.light)? themeData.colorScheme.primary: themeData.colorScheme.surfaceVariant;
    var onBackground = (themeData.brightness == Brightness.light)? themeData.colorScheme.onPrimary: themeData.colorScheme.onSurfaceVariant;

    return DrawerHeader(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.only(left: 10, right: 10, top: 30),
        decoration: BoxDecoration(color: background),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image(
                          height: 60,
                          width: 60,
                          image: brandingIcon ??
                              AssetImage('assets/icon/mr_logo.png')),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.selectedPrinterDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: themeData.textTheme.titleLarge?.copyWith(
                                  color:onBackground),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model.printerUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: themeData.textTheme.subtitle2?.copyWith(
                                  color: onBackground),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                    onPressed: () => model.onEditTap(null),
                    tooltip: 'components.nav_drawer.printer_settings'.tr(),
                    icon: Icon(
                      FlutterIcons.settings_fea,
                      color: onBackground,
                      size: 27,
                    ))
              ],
            ),
            ListTile(
              title: Text(
                'components.nav_drawer.manage_printers',
                style: TextStyle(color: onBackground),
              ).tr(),
              trailing: Icon(
                model.isManagePrintersExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                color: onBackground,
              ),
              onTap: model.toggleManagePrintersExpanded,
            )
          ],
        ));
  }
}

class _DrawerItem extends ViewModelWidget<NavDrawerViewModel> {
  _DrawerItem(
      {required this.text,
      required this.icon,
      required this.path,
      this.onClicked});

  final String text;
  final IconData icon;
  final String path;
  final VoidCallback? onClicked;

  @override
  Widget build(BuildContext context, NavDrawerViewModel model) {
    var themeData = Theme.of(context);
    var selectedTileColor = (themeData.brightness == Brightness.light)? themeData.colorScheme.surfaceVariant:themeData.colorScheme.primaryContainer.withOpacity(.1);

    return ListTile(
      selected: model.isSelected(path),
      selectedTileColor: selectedTileColor,
      selectedColor: themeData.colorScheme.secondary,
      textColor: themeData.colorScheme.onBackground,
      leading: Icon(icon),
      title: Text(text),
      onTap: onClicked ?? () => model.navigateMenu(path),
    );
  }
}

class _PrinterSelection extends ViewModelWidget<NavDrawerViewModel> {
  @override
  Widget build(BuildContext context, NavDrawerViewModel model) {
    List<Machine> printers = model.dataReady ? model.printers : [];
    var themeData = Theme.of(context);
    var onBackGroundColor = themeData.colorScheme.onBackground;
    var selectedTileColor = (themeData.brightness == Brightness.light)? themeData.colorScheme.surfaceVariant:themeData.colorScheme.primaryContainer.withOpacity(.1);
    const double baseIconSize = 20;
    const basePadding = const EdgeInsets.only(left: 16, right: 16);
    return AnimatedContainer(
      height: model.isManagePrintersExpanded
          ? kToolbarHeight * (printers.length + 1)
          : 0,
      duration: kThemeAnimationDuration,
      curve: Curves.ease,
      child: AnimatedOpacity(
        opacity: model.isManagePrintersExpanded ? 1 : 0,
        duration: kThemeAnimationDuration,
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            if (!model.dataReady)
              ListTile(
                title:
                    FadingText('components.nav_drawer.fetching_printers'.tr()),
                contentPadding: basePadding,
              )
            else
              ...List.generate(printers.length, (index) {
                Machine curPS = printers[index];
                return ListTile(
                  title: Text(
                    curPS.name,
                    maxLines: 1,
                  ),
                  trailing: Icon(
                    index == 0 ? Icons.check : Icons.arrow_forward_ios_sharp,
                    size: baseIconSize,
                  ),
                  selectedTileColor: model.isManagePrintersExpanded
                      ? selectedTileColor
                      : Colors.transparent,
                  selectedColor: themeData.colorScheme.secondary,
                  textColor: onBackGroundColor,
                  iconColor: onBackGroundColor,
                  contentPadding: basePadding,
                  selected: index == 0,
                  onTap: () => model.onSetActiveTap(curPS),
                  onLongPress: () => model.onEditTap(curPS),
                );
              }),
            ListTile(
              title: Text('pages.printer_add.title').tr(),
              contentPadding: basePadding,
              textColor: onBackGroundColor,
              iconColor: onBackGroundColor,
              trailing: Icon(
                Icons.add,
                size: baseIconSize,
              ),
              onTap: () => model.navigateTo(Routes.printerAdd),
            )
          ],
        ),
      ),
    );
  }
}
