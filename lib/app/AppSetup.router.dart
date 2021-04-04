// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedRouterGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../ui/overview/overview_view.dart';
import '../ui/setting/setting_view.dart';
import '../ui/test_view.dart';

class Routes {
  static const String overView = '/';
  static const String settingView = '/setting-view';
  static const String testView = '/test-view';
  static const all = <String>{
    overView,
    settingView,
    testView,
  };
}

class StackedRouter extends RouterBase {
  @override
  List<RouteDef> get routes => _routes;
  final _routes = <RouteDef>[
    RouteDef(Routes.overView, page: OverView),
    RouteDef(Routes.settingView, page: SettingView),
    RouteDef(Routes.testView, page: TestView),
  ];
  @override
  Map<Type, StackedRouteFactory> get pagesMap => _pagesMap;
  final _pagesMap = <Type, StackedRouteFactory>{
    OverView: (data) {
      return MaterialPageRoute<dynamic>(
        builder: (context) => const OverView(),
        settings: data,
      );
    },
    SettingView: (data) {
      return CupertinoPageRoute<dynamic>(
        builder: (context) => const SettingView(),
        settings: data,
      );
    },
    TestView: (data) {
      return CupertinoPageRoute<dynamic>(
        builder: (context) => const TestView(),
        settings: data,
      );
    },
  };
}
