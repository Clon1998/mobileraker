/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/fold_bridge.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:test_support/test_support.dart';

/// Two destinations in the rail.
class _FakeNav extends NavWidgetController {
  @override
  NavWidgetModel build() => const NavWidgetModel(
    entries: [
      NavEntry(label: 'Dashboard', icon: Icons.dashboard, route: '/'),
      NavEntry(label: 'Files', icon: Icons.folder, route: '/files'),
    ],
  );
}

class _NoMachines extends AllMachines {
  @override
  Future<List<Machine>> build() async => [];
}

// 1x1 transparent PNG, so the rail's branding icon doesn't try to load an asset.
final _pixel = MemoryImage(
  base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
);

final _overrides = [
  navWidgetControllerProvider.overrideWith(_FakeNav.new),
  allMachinesProvider.overrideWith(_NoMachines.new),
  activeThemeProvider.overrideWithValue(
    AsyncData(ThemeModel(ThemePack(name: 'test', lightTheme: ThemeData(), brandingIcon: _pixel), ThemeMode.light)),
  ),
];

/// A page of the app: app bar, drawer, optional FAB.
class _Page extends StatelessWidget {
  const _Page(this.title, {this.fab = false});

  final String title;
  final bool fab;

  @override
  Widget build(BuildContext context) {
    return RailScaffold(
      appBar: AppBar(title: Text(title), leading: RailScaffold.impliedLeadingOf(context)),
      drawer: Drawer(child: Center(child: Text('Drawer of $title'))),
      floatingActionButton: fab ? FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)) : null,
      body: Center(child: Text('Body of $title')),
    );
  }
}

GoRouter _router({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) => NavigationRailShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const _Page('Dashboard', fab: true),
          routes: [GoRoute(path: 'sub', builder: (_, _) => const _Page('Sub'))],
        ),
        GoRoute(path: '/files', builder: (_, _) => const _Page('Files')),
      ],
    ),
    // Covers the shell, like detail pages and forms.
    GoRoute(path: '/details', builder: (_, _) => const _Page('Details', fab: true)),
  ],
);

final _railEntry = find.byIcon(Icons.folder);
final _fab = find.byType(FloatingActionButton);
final _menuButton = find.byIcon(Icons.menu);
final _appBar = find.byType(AppBar);
final _appBarDrawerButton = find.descendant(of: _appBar, matching: find.byType(DrawerButton));

void main() {
  setUpWidgetTests();

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    required TestDevice device,
    String initialLocation = '/',
    TextDirection? textDirection,
  }) async {
    final router = _router(initialLocation: initialLocation);
    await tester.pumpRouterApp(router, device: device, overrides: _overrides, textDirection: textDirection);
    // The page hands its app bar/FAB to the shell after the first frame.
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> go(WidgetTester tester, GoRouter router, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  group('phone', () {
    testWidgets('has no rail; the page shows its own app bar with drawer button and FAB', (tester) async {
      await pumpShell(tester, device: TestDevice.phone);

      expect(_railEntry, findsNothing);
      expect(_appBarDrawerButton, findsOneWidget);
      expect(tester.getCenter(_fab).dx, greaterThan(TestDevice.phone.size.width / 2));
    });

    testWidgets('the drawer button opens the page drawer', (tester) async {
      await pumpShell(tester, device: TestDevice.phone);

      await tester.tap(_appBarDrawerButton);
      await tester.pumpAndSettle();

      expect(find.text('Drawer of Dashboard'), findsOneWidget);
    });
  });

  group('tablet', () {
    testWidgets('shows the rail on the left with the FAB on top of it', (tester) async {
      await pumpShell(tester, device: TestDevice.tablet);

      expect(_railEntry, findsOneWidget);
      expect(tester.getCenter(_railEntry).dx, lessThan(72));
      expect(tester.getCenter(_fab).dx, lessThan(72));
      expect(tester.getCenter(_fab).dy, lessThan(tester.getCenter(_railEntry).dy));
      expect(find.text('Dashboard'), findsOneWidget);
      expect(_appBarDrawerButton, findsOneWidget);
    });

    testWidgets('a rail entry switches the destination and its app bar/FAB', (tester) async {
      await pumpShell(tester, device: TestDevice.tablet);

      await tester.tap(_railEntry);
      await tester.pumpAndSettle();

      expect(find.text('Body of Files'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(_fab, findsNothing);
    });

    testWidgets('a sub-page within the shell gets a back button that pops it', (tester) async {
      final router = await pumpShell(tester, device: TestDevice.tablet);

      await go(tester, router, '/sub');
      expect(find.text('Sub'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Body of Dashboard'), findsOneWidget);
    });

    testWidgets('a page covering the shell is a regular page with its own FAB', (tester) async {
      final router = await pumpShell(tester, device: TestDevice.tablet);

      await go(tester, router, '/details');

      expect(_railEntry, findsNothing);
      expect(tester.getCenter(_fab).dx, greaterThan(TestDevice.tablet.size.width / 2));
    });
  });

  group('iPhone Duo', () {
    final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

    FoldStrip stripOf(WidgetTester tester) => tester.element(find.byType(MaterialApp)).foldStrip!;

    void expectInStrip(WidgetTester tester, Finder finder, FoldStrip strip) {
      final center = tester.getCenter(finder);
      expect(strip.rect.contains(center), isTrue, reason: '$finder at $center is outside of the strip ${strip.rect}');
      expect(center.dy, greaterThan(strip.topClearance), reason: 'below the status cluster');
    }

    testWidgets('inner landscape: the rail and the FAB fill the strip on the right', (tester) async {
      await pumpShell(tester, device: TestDevice.duoInnerLandscape);
      final strip = stripOf(tester);

      expect(strip.side, FoldStripSide.right);
      expectInStrip(tester, _railEntry, strip);
      expectInStrip(tester, _fab, strip);
      expectInStrip(tester, _menuButton, strip);
      expect(tester.getSize(_fab), const Size(44, 44), reason: 'smaller FAB in the strip');
    }, variant: iOS);

    testWidgets('inner landscape: the app bar stays out of the strip and has no drawer button', (tester) async {
      await pumpShell(tester, device: TestDevice.duoInnerLandscape);
      final strip = stripOf(tester);

      expect(tester.getRect(_appBar).right, lessThanOrEqualTo(strip.rect.left));
      expect(_appBarDrawerButton, findsNothing);
    }, variant: iOS);

    testWidgets('the menu button opens the drawer from the strip side', (tester) async {
      await pumpShell(tester, device: TestDevice.duoInnerLandscape);

      await tester.tap(_menuButton);
      await tester.pumpAndSettle();

      final drawer = tester.getRect(find.byType(Drawer));
      expect(find.text('Drawer of Dashboard'), findsOneWidget);
      expect(drawer.right, TestDevice.duoInnerLandscape.size.width);
    }, variant: iOS);

    testWidgets('in RTL the strip stays on the right and the drawer opens there', (tester) async {
      await pumpShell(tester, device: TestDevice.duoInnerLandscape, textDirection: TextDirection.rtl);
      final strip = stripOf(tester);

      expectInStrip(tester, _railEntry, strip);
      await tester.tap(_menuButton);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(Drawer)).right, TestDevice.duoInnerLandscape.size.width);
    }, variant: iOS);

    testWidgets('switching between pages with and without FAB keeps the rail entries and menu in place', (tester) async {
      final router = await pumpShell(tester, device: TestDevice.duoInnerLandscape);
      final entryBefore = tester.getRect(_railEntry);
      final menuBefore = tester.getRect(_menuButton);

      await go(tester, router, '/files');
      expect(_fab, findsNothing);
      expect(tester.getRect(_railEntry), entryBefore);
      expect(tester.getRect(_menuButton), menuBefore);

      await go(tester, router, '/');
      expect(_fab, findsOneWidget);
      expect(tester.getRect(_railEntry), entryBefore);
    }, variant: iOS);

    testWidgets('a page covering the shell shows its FAB in the strip, below the status cluster', (tester) async {
      final router = await pumpShell(tester, device: TestDevice.duoInnerLandscape);
      final strip = stripOf(tester);

      await go(tester, router, '/details');

      expect(_railEntry, findsNothing);
      expectInStrip(tester, _fab, strip);
      expect(tester.getRect(_appBar).right, lessThanOrEqualTo(strip.rect.left));
      // The page keeps its own drawer button, there is no menu in the strip.
      expect(_appBarDrawerButton, findsOneWidget);
    }, variant: iOS);

    testWidgets('cover display: the rail fills the strip', (tester) async {
      await pumpShell(tester, device: TestDevice.duoCover);
      final strip = stripOf(tester);

      expectInStrip(tester, _railEntry, strip);
      expectInStrip(tester, _menuButton, strip);
    }, variant: iOS);

    testWidgets('inner portrait has no strip: the regular rail on the left', (tester) async {
      await pumpShell(tester, device: TestDevice.duoInnerPortrait);

      expect(tester.element(find.byType(MaterialApp)).foldStrip, isNull);
      expect(tester.getCenter(_railEntry).dx, lessThan(72));
      // The only menu icon is the app bar's drawer button.
      expect(_menuButton, findsOneWidget);
      expect(_appBarDrawerButton, findsOneWidget);
    }, variant: iOS);
  });
}
