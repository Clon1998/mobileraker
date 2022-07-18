import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher_string.dart';

const String packageFuture = 'packageFuture';
const String notifiFuture = 'notifFuture';

class SettingViewModel extends MultipleFutureViewModel {
  final _logger = getLogger("SettingViewModel");
  final _settingService = locator<SettingService>();
  final _navigationService = locator<NavigationService>();
  final _notificationService = locator<NotificationService>();

  PackageInfo get packageInfo => dataMap![packageFuture];

  bool get hasPackageInfoReady => !isBusy && dataReady(packageFuture);

  bool get notificationPermissionGranted => dataMap![notifiFuture];

  bool get hasNotificationPermissionGrantedReady =>
      !isBusy && dataReady(notifiFuture);

  // late final WebSocketWrapper _jRpcClient = _machineService.webSocket;
  GlobalKey get formKey => _fbKey;
  final _fbKey = GlobalKey<FormBuilderState>();

  bool get emsValue => _settingService.readBool(emsKey);

  bool get showBabyAlwaysValue => _settingService.readBool(showBabyAlwaysKey);

  bool get useTextInputForNum =>
      _settingService.readBool(useTextInputForNumKey);

  bool get startWithOverview => _settingService.readBool(startWithOverviewKey);

  ProgressNotificationMode get progressNotificationMode {
    int readInt = _settingService.readInt(selectedProgressNotifyMode, -1);
    if (readInt < 0) return ProgressNotificationMode.TWENTY_FIVE;

    return ProgressNotificationMode.values[readInt];
  }

  String get version {
    if (!hasPackageInfoReady) return "Version: unavailable";
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    return "Version: $version-$buildNumber";
  }

  List<ThemeMode> get themeModes => ThemeMode.values;

  @override
  Map<String, Future Function()> get futuresMap => {
        packageFuture: () => PackageInfo.fromPlatform(),
        notifiFuture: () => _notificationService.hasNotificationPermission(),
      };

  onRequestPermission() async {
    var bool = await _notificationService.requestNotificationPermission();
     dataMap![notifiFuture] = bool;
     notifyListeners();
  }

  onEMSChanged(bool? newVal) {
    _settingService.writeBool(emsKey, newVal ?? false);
  }

  onAlwaysShowBabyChanged(bool? newVal) {
    _settingService.writeBool(showBabyAlwaysKey, newVal ?? false);
  }

  onUseTextInputForNumChanged(bool? newVal) {
    _settingService.writeBool(useTextInputForNumKey, newVal ?? false);
  }

  onStartWithOverviewChanged(bool? newVal) {
    _settingService.writeBool(startWithOverviewKey, newVal ?? false);
  }

  onProgressNotifyModeChanged(ProgressNotificationMode? mode) {
    if (mode == null) return;
    _settingService.writeInt(selectedProgressNotifyMode, mode.index);
  }

  onCompanionTapped() async {
    const String url = 'https://github.com/Clon1998/mobileraker_companion';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      throw 'Could not launch $url';
    }
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
      String country =
          'languages.countryCode.${local.countryCode}.nativeName'.tr();
      out += " ($country)";
    }
    return out;
  }
}
