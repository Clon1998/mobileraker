/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';

class DevPage extends StatelessWidget {
  const DevPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Dev'),
        ),
        drawer: const NavigationDrawerWidget(),
        body: Column(
          children: [
            Text('One'),
            // Expanded(child: WebRtcCam()),
          ],
        ));
  }
}
