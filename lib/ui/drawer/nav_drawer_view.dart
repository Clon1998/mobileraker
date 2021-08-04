import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NavigationDrawerWidget extends StatelessWidget {
  final String curPath;

  NavigationDrawerWidget({required this.curPath});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<NavDrawerViewModel>.reactive(
      builder: (context, model, child) => Drawer(
        child: Material(
          color: Color.fromRGBO(50, 75, 205, 1),
          child: ListView(
            children: <Widget>[
              buildHeader(
                name: model.printerDisplayName,
                email: Uri.parse(model.printerUrl).host,
                onClicked: () => model.navigateTo(Routes.printers),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 00),
                child: Column(
                  children: [
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
                      onClicked: () => model.notImpl(),
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

  Widget buildHeader({
    required String name,
    required String email,
    required VoidCallback onClicked,
  }) =>
      Container(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Row(
          children: [
            CircleAvatar(
                radius: 30,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage('assets/images/voron_design.png')),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  overflow: TextOverflow.fade,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
            Spacer(),
            IconButton(
                onPressed: onClicked,
                icon: Icon(
                  FlutterIcons.printer_3d_mco,
                  color: Colors.white,
                  size: 36,
                ))
          ],
        ),
      );

  Widget buildMenuItem(NavDrawerViewModel model,{
    required String text,
    required IconData icon,
    required String path,
    VoidCallback? onClicked,
  }) {
    final color = Colors.white;
    final hoverColor = Colors.white70;
    if (onClicked == null)
      onClicked = () => model.navigateTo(path);

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
