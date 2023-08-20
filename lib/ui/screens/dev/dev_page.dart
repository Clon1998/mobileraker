/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcams/cam_card.dart';

class DevPage extends StatelessWidget {
  const DevPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.blueGrey,
        appBar: AppBar(
          title: const Text('Dev'),
        ),
        drawer: const NavigationDrawerWidget(),
        body: ListView(
          children: [
            Text('One'),
            CamCard(),
            // Expanded(child: WebRtcCam()),
          ],
        ));
  }
}
