import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/data/datasource/moonraker_database_client.dart';
import 'package:mobileraker/data/repository/machine_hive_repository.dart';
import 'package:mobileraker/data/repository/machine_settings_moonraker_repository.dart';
import 'package:mobileraker/model/hive/gcode_macro.dart';
import 'package:mobileraker/model/hive/machine.dart';
import 'package:mobileraker/model/hive/macro_group.dart';
import 'package:mobileraker/model/hive/temperature_preset.dart';
import 'package:mobileraker/model/hive/webcam_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/purchases_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/connection/connection_state_viewmodel.dart';
import 'package:mobileraker/ui/views/console/console_view.dart';
import 'package:mobileraker/ui/views/console/console_viewmodel.dart';
import 'package:mobileraker/ui/views/dashboard/dashboard_view.dart';
import 'package:mobileraker/ui/views/dashboard/tabs/control_tab_viewmodel.dart';
import 'package:mobileraker/ui/views/dashboard/tabs/general_tab_viewmodel.dart';
import 'package:mobileraker/ui/views/files/details/config_file_details_view.dart';
import 'package:mobileraker/ui/views/files/details/gcode_file_details_view.dart';
import 'package:mobileraker/ui/views/files/files_view.dart';
import 'package:mobileraker/ui/views/fullcam/full_cam_view.dart';
import 'package:mobileraker/ui/views/overview/overview_view.dart';
import 'package:mobileraker/ui/views/paywall/paywall_view.dart';
import 'package:mobileraker/ui/views/printers/add/printers_add_view.dart';
import 'package:mobileraker/ui/views/printers/edit/printers_edit_view.dart';
import 'package:mobileraker/ui/views/printers/qr_scanner/qr_scanner_view.dart';
import 'package:mobileraker/ui/views/setting/imprint/imprint_view.dart';
import 'package:mobileraker/ui/views/setting/setting_view.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';

@StackedApp(routes: [
  MaterialRoute(page: DashboardView, initial: true),
  MaterialRoute(page: FullCamView),
  MaterialRoute(page: PrinterAdd),
  MaterialRoute(page: PrinterEdit),
  MaterialRoute(page: FilesView),
  MaterialRoute(page: GCodeFileDetailView),
  MaterialRoute(page: ConfigFileDetailView),
  MaterialRoute(page: SettingView),
  MaterialRoute(page: ImprintView),
  MaterialRoute(page: QrScannerView),
  MaterialRoute(page: ConsoleView),
  MaterialRoute(page: PaywallView),
  MaterialRoute(page: OverViewView),
], dependencies: [
  Singleton(classType: NavigationService),
  LazySingleton(classType: SnackbarService),
  // LazySingleton(classType: machineHiveRepository, asType: machineRepository,),
  LazySingleton(classType: DialogService),
  LazySingleton(classType: BottomSheetService),
  LazySingleton(classType: GeneralTabViewModel),
  LazySingleton(classType: ControlTabViewModel),
  LazySingleton(classType: ConnectionStateViewModel),
  LazySingleton(classType: ConsoleViewModel),
  LazySingleton(classType: PurchasesService),
  Singleton(classType: MachineHiveRepository),
  Singleton(classType: SelectedMachineService),
  Singleton(classType: MoonrakerDatabaseClient),
  Singleton(classType: MachineSettingsMoonrakerRepository),
  Singleton(classType: MachineService),
  Singleton(classType: SettingService),
  Singleton(classType: NotificationService),
], logger: StackedLogger())
class AppSetup {}

setupBoxes() async {
  await Hive.initFlutter();
  var machineAdapter = MachineAdapter();
  if (!Hive.isAdapterRegistered(machineAdapter.typeId))
    Hive.registerAdapter(machineAdapter);
  var webcamSettingAdapter = WebcamSettingAdapter();
  if (!Hive.isAdapterRegistered(webcamSettingAdapter.typeId))
    Hive.registerAdapter(webcamSettingAdapter);
  var temperaturePresetAdapter = TemperaturePresetAdapter();
  if (!Hive.isAdapterRegistered(temperaturePresetAdapter.typeId))
    Hive.registerAdapter(temperaturePresetAdapter);
  var macroGrpAdapter = MacroGroupAdapter();
  if (!Hive.isAdapterRegistered(macroGrpAdapter.typeId))
    Hive.registerAdapter(macroGrpAdapter);
  var macroAdapter = GCodeMacroAdapter();
  if (!Hive.isAdapterRegistered(macroAdapter.typeId))
    Hive.registerAdapter(macroAdapter);
  // Hive.deleteBoxFromDisk('printers');

  try {
    await openBoxes();
  } catch (e) {
    await Hive.deleteBoxFromDisk('printers');
    await Hive.deleteBoxFromDisk('uuidbox');
    await Hive.deleteBoxFromDisk('settingsbox');
    await openBoxes();
  }
}

Future<List<Box>> openBoxes() {
  return Future.wait([
    Hive.openBox<Machine>('printers'),
    Hive.openBox<String>('uuidbox'),
    Hive.openBox('settingsbox'),
  ]);
}

Future<void> setupCat() async {
  if (kReleaseMode) return;
  if (kDebugMode) await Purchases.setDebugLogsEnabled(true);
  if (Platform.isAndroid) {
    return Purchases.setup('goog_uzbmaMIthLRzhDyQpPsmvOXbaCK');
  }
}

setupLicenseRegistry() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
}
