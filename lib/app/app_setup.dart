import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/domain/gcode_macro.dart';
import 'package:mobileraker/domain/macro_group.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/views/files/details/file_details_view.dart';
import 'package:mobileraker/ui/views/files/files_view.dart';
import 'package:mobileraker/ui/views/fullcam/full_cam_view.dart';
import 'package:mobileraker/ui/views/overview/overview_view.dart';
import 'package:mobileraker/ui/views/overview/tabs/general_tab_viewmodel.dart';
import 'package:mobileraker/ui/views/printers/add/printers_add_view.dart';
import 'package:mobileraker/ui/views/printers/edit/printers_edit_view.dart';
import 'package:mobileraker/ui/views/setting/setting_view.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';

@StackedApp(routes: [
  MaterialRoute(page: OverView, initial: true),
  MaterialRoute(page: FullCamView),
  MaterialRoute(page: PrintersAdd),
  MaterialRoute(page: PrintersEdit),
  MaterialRoute(page: FilesView),
  MaterialRoute(page: FileDetailView),
  MaterialRoute(page: SettingView),
], dependencies: [
  LazySingleton(classType: NavigationService),
  LazySingleton(classType: SnackbarService),
  LazySingleton(classType: DialogService),
  LazySingleton(classType: BottomSheetService),
  LazySingleton(classType: GeneralTabViewModel),
  Singleton(classType: MachineService),
  Singleton(classType: SettingService),
  Singleton(classType: NotificationService),
], logger: StackedLogger())
class AppSetup {}

setupBoxes() async {
  await Hive.initFlutter();
  var printerSettingAdapter = PrinterSettingAdapter();
  if (!Hive.isAdapterRegistered(printerSettingAdapter.typeId))
    Hive.registerAdapter(printerSettingAdapter);
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
    Hive.openBox<PrinterSetting>('printers'),
    Hive.openBox<String>('uuidbox'),
    Hive.openBox('settingsbox'),
  ]);
}
