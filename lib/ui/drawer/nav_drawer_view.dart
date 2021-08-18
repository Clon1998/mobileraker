import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_viewmodel.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';

class NavigationDrawerWidget extends StatelessWidget {
  final String curPath;

  NavigationDrawerWidget({required this.curPath});

  @override
  Widget build(BuildContext context) {
    Color bgCol = Color.fromRGBO(50, 75, 205, 1);
    var themeData = Theme.of(context);
    if (themeData.brightness == Brightness.dark) bgCol = themeData.primaryColor;
    return ViewModelBuilder<NavDrawerViewModel>.reactive(
      builder: (context, model, child) => Drawer(
        child: Material(
          color: bgCol,
          child: ListView(
            children: <Widget>[
              buildHeader(
                name: model.printerDisplayName,
                email: model.printerUrl,
                onClicked: () => model.onEditTap(null),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 00),
                child: Column(
                  children: [
                    ExpansionTile(
                      title: const Text(
                        'Manager Printers',
                        style: TextStyle(color: Colors.white),
                      ),
                      children: buildPrinterSelection(context, model),
                    ),
                    buildMenuItem(
                      model,
                      text: 'Overview',
                      icon: Icons.home,
                      path: Routes.overView,
                    ),

                    buildMenuItem(
                      model,
                      text: 'Files',
                      icon: Icons.file_present,
                      path: '',
                      onClicked: () => showWIPSnackbar(),
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
            ],
          ),
        ),
      ),
      viewModelBuilder: () => NavDrawerViewModel(curPath),
    );
  }

  // Note always the first is the currently selected!
  List<Widget> buildPrinterSelection(
      BuildContext context, NavDrawerViewModel model) {
    var theme = Theme.of(context);
    Color highlightColor = theme.brightness == Brightness.dark
        ? theme.accentColor
        : theme.primaryColor;

    List<PrinterSetting> printers = model.printers;
    var textStyle = TextStyle(color: Colors.white);
    return List.generate(printers.length + 1, (index) {
      if (index == printers.length) {
        return ListTile(
          title: Text('Add new printer', style: textStyle),
          contentPadding: EdgeInsets.only(left: 32, right: 16),
          trailing: Icon(Icons.add, color: highlightColor),
          onTap: () => model.navigateTo(Routes.printersAdd),
        );
      }
      PrinterSetting curPS = printers[index];

      return ListTile(
        title: Text(
          curPS.name,
          maxLines: 1,
          style: textStyle,
        ),
        trailing: Icon(index == 0 ? Icons.check : Icons.arrow_forward_ios_sharp,
            color: highlightColor),
        selectedTileColor: Colors.white12,
        contentPadding: EdgeInsets.only(left: 32, right: 16),
        selected: index == 0,
        onTap: () => model.onSetActiveTap(curPS),
        onLongPress: () => model.onEditTap(curPS),
      );
    });
  }

  Widget buildHeader({
    required String name,
    required String email,
    required VoidCallback onClicked,
  }) =>
      Container(
        margin: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
                radius: 30,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage('assets/icon/mr_logo.png')),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
                onPressed: onClicked,
                tooltip: 'Printer settings',
                icon: Icon(
                  FlutterIcons.settings_fea,
                  color: Colors.white,
                  size: 27,
                ))
          ],
        ),
      );

  Widget buildMenuItem(
    NavDrawerViewModel model, {
    required String text,
    required IconData icon,
    required String path,
    VoidCallback? onClicked,
  }) {
    final color = Colors.white;
    final hoverColor = Colors.white70;
    if (onClicked == null) onClicked = () => model.navigateTo(path);

    return ListTile(
      selected: model.isSelected(path),
      selectedTileColor: Colors.white12,
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
      hoverColor: hoverColor,
      onTap: onClicked,
    );
  }

// Widget buildFooter() {
//   return Row(children: [
//     TextButton(onPressed: onPressed, child: Text('Imprint'))
//   ]);
// }
}
