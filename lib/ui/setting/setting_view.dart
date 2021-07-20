import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:mobileraker/ui/setting/setting_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:validators/validators.dart';

class SettingView extends StatelessWidget {
  const SettingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<SettingViewModel>.reactive(
      viewModelBuilder: () => SettingViewModel(),
      builder: (context, model, child) => Container(
          child: SettingsScreen(
        title: "Settings",
        children: [
          SettingsGroup(
              title: "Klipper",
              subtitle: "Klipper related settings",
              children: [
                TextInputSettingsTile(
                  settingKey: 'klipper.url',
                  title: 'Klipper-Address',
                  initialValue: "ws://mainsailos.local/websocket",
                  validator: (String? url) {
                    if (url != null &&
                        url.length > 0 &&
                        isURL(url, protocols: ['ws', 'wss'])) {
                      return null;
                    }
                    return "No WebSocket url";
                  },
                  onChange: model.onUrlChanged,
                ),
                TextInputSettingsTile(
                  title: 'Name',
                  settingKey: 'klipper.name',
                  initialValue: 'Printer',
                  validator: (String? username) {
                    if (username != null && username.length > 3) {
                      return null;
                    }
                    return "Name can't be smaller than 4 letters"; //TODO
                  },
                  borderColor: Colors.blueAccent,
                  errorColor: Colors.deepOrangeAccent,
                  onChange: (val) => model.testNotify(),
                ),
              ]),
          SettingsGroup(
            title: 'Notification',
            subtitle: 'Notification realted settings',
            children: <Widget>[
              SwitchSettingsTile(
                settingKey: 'notify.klipper-changed',
                title: 'Klipper-State changed',
                subtitle: 'Get status Updates about the print',
                leading: Icon(FlutterIcons.printer_3d_mco),
                defaultValue: false,
              ),
              SwitchSettingsTile(
                settingKey: 'notify.printer-changed',
                title: 'Printer-State changed',
                subtitle: 'Get status Updates about the print',
                leading: Icon(FlutterIcons.server_network_mco),
                defaultValue: false,
              ),
            ],
          ),
        ],
      )),
    );
  }
}

// Widget buildSettingsList() {
// return Padding(
//   padding: const EdgeInsets.fromLTRB(0,12,0,0),
//   child: SettingsList(
//     sections: [
//       SettingsSection(
//         title: 'Klipper - Server',
//         tiles: [
//           SettingsTile(
//               title: 'URL',
//               leading: Icon(FontAwesomeIcons.server),
//
//           ),
//         ],
//       ),
//       SettingsSection(
//         title: 'Notifications',
//         tiles: [
//           SettingsTile.switchTile(
//             title: 'Klipper-State changed',
//             leading: Icon(Icons.phonelink_lock),
//             switchValue: true,
//             onToggle: (bool value) {
//
//             },
//           ),
//           SettingsTile.switchTile(
//               title: 'Printing',
//               subtitle: 'Get status Updates about the print.',
//               leading: Icon(Icons.fingerprint),
//               onToggle: (bool value) {},
//               switchValue: false),
//         ],
//       ),
//       CustomSection(
//         child: Column(
//           children: [
//             Text(
//               'Version: 2.4.0 (287)',
//               style: TextStyle(color: Color(0xFF777777)),
//             ),
//           ],
//         ),
//       ),
//     ],
//   ),
// );
// }
