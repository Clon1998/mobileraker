import 'package:flutter/material.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';

class MyTestHomeScreen extends StatelessWidget {
  const MyTestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My App Test'),
      ),
      body: Center(
        child: ConnectionStateView(
          onConnected: PullToRefreshPrinter(child: Text('Yes I am connected!')),
        ),
      ),
    );
  }
}
