import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rxdart/rxdart.dart';

final importTarget = Provider.autoDispose<String>(name: 'importTarget', (ref) {
  throw UnimplementedError();
});

final usingIt = Provider.autoDispose<String>(name: 'usingIt', (ref) {
  return '${ref.watch(importTarget)}......';
});

class TestPage extends ConsumerWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
        overrides: [importTarget.overrideWithValue('MyPassedValue')],
        child: const Body());
  }
}

class Body extends ConsumerWidget {
  const Body({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Text('Data of a:  ${ref.watch(usingIt)}'),
          ],
        ),
      ),
    );
  }
}
