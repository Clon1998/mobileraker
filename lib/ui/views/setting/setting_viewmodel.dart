import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class SettingViewModel extends FutureViewModel<PackageInfo> {
  final _logger = getLogger("SettingViewModel");
  final _settingService = locator<SettingService>();
  final _navigationService = locator<NavigationService>();

  // late final WebSocketWrapper _jRpcClient = _machineService.webSocket;
  GlobalKey get formKey => _fbKey;
  final _fbKey = GlobalKey<FormBuilderState>();

  bool get emsValue => _settingService.readBool(emsKey);

  bool get showBabyAlwaysValue => _settingService.readBool(showBabyAlwaysKey);

  bool get useTextInputForNum =>
      _settingService.readBool(useTextInputForNumKey);

  bool get startWithOverview => _settingService.readBool(startWithOverviewKey);

  String get version {
    if (isBusy) return "Version: unavailable";
    PackageInfo packageInfo = data!;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    return "Version: $version-$buildNumber";
  }

  List<ThemeMode> get themeModes => ThemeMode.values;

  @override
  Future<PackageInfo> futureToRun() => PackageInfo.fromPlatform();

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

  navigateToLicensePage(BuildContext context) {
    showLicensePage(
        context: context,
        applicationVersion: version,
        applicationLegalese:
            'MIT License\n\nCopyright (c) 2021 Patrick Schmidt',
        applicationIcon: Center(
          child: Image(
              height: 80,
              width: 80,
              image: AssetImage('assets/icon/mr_logo.png')),
        ));
  }

  String constructLanguageText(Locale local) {
    String out = 'languages.languageCode.${local.languageCode}.nativeName'.tr();

    if (local.countryCode != null) {
      String country = 'languages.countryCode.${local.countryCode}.nativeName'.tr();
        out += " ($country)";
    }
    return out;
  }
}
