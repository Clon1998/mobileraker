// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedLocatorGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs

import 'package:simple_logger/simple_logger.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import '../WsHelper.dart';
import '../service/KlippyService.dart';
import '../service/PrinterService.dart';

final locator = StackedLocator.instance;

void setupLocator() {
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => SnackbarService());
  locator.registerLazySingleton(() => DialogService());
  locator.registerLazySingleton(() => PrinterService());
  locator.registerLazySingleton(() => KlippyService());
  locator.registerLazySingleton(() => SimpleLogger());
  locator.registerSingleton(WebSocketsNotifications());
}
