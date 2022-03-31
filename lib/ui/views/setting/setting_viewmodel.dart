import 'package:flutter/cupertino.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String emsKey = 'ems_setting';
const String showBabyAlwaysKey = 'always_babystepping_setting';
const String useTextInputForNumKey = 'text_inpt_for_num_fields';
const String startWithOverviewKey = 'start_with_overview';

class SettingViewModel extends FutureViewModel<PackageInfo> {
  final _logger = getLogger("SettingViewModel");
  final _settingService = locator<SettingService>();
  final _navigationService = locator<NavigationService>();

  // late final WebSocketWrapper _webSocket = _machineService.webSocket;
  final _fbKey = GlobalKey<FormBuilderState>();

  GlobalKey get formKey => _fbKey;

  onEMSChanged(bool? newVal) async {
    await _settingService.writeBool(emsKey, newVal ?? false);
  }

  onAlwaysShowBabyChanged(bool? newVal) async {
    await _settingService.writeBool(showBabyAlwaysKey, newVal ?? false);
  }

  onUseTextInputForNumChanged(bool? newVal) async {
    await _settingService.writeBool(useTextInputForNumKey, newVal ?? false);
  }

  onStartWithOverviewChanged(bool? newVal) async {
    await _settingService.writeBool(startWithOverviewKey, newVal ?? false);
  }


  bool get emsValue => _settingService.readBool(emsKey);

  bool get showBabyAlwaysValue => _settingService.readBool(showBabyAlwaysKey);

  bool get useTextInputForNum => _settingService.readBool(useTextInputForNumKey);

  bool get startWithOverview => _settingService.readBool(startWithOverviewKey);

  @override
  Future<PackageInfo> futureToRun() => PackageInfo.fromPlatform();

  void navigateToLegal() {
    _navigationService.navigateTo(Routes.imprintView);
  }

  String get version {
    if (isBusy) return "Version: unavailable";
    PackageInfo packageInfo = data!;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    return "Version: $version-$buildNumber";
  }
}
