/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'date_format_service.g.dart';

@riverpod
DateFormatService dateFormatService(DateFormatServiceRef ref) {
  var settingService = ref.watch(settingServiceProvider);
  return DateFormatService(settingService);
}

class DateFormatService {
  final SettingService _settingService;

  DateFormatService(this._settingService);

  DateFormat Hm() {
    var isFreedomUnit = _settingService.readBool(timeMode);

    return isFreedomUnit ? DateFormat.jm() : DateFormat.Hm();
  }

  DateFormat Hms() {
    var isFreedomUnit = _settingService.readBool(timeMode);

    return isFreedomUnit ? DateFormat.jms() : DateFormat.Hms();
  }

  DateFormat add_Hm(DateFormat format) {
    var isFreedomUnit = _settingService.readBool(timeMode);

    return isFreedomUnit ? format.add_jm() : format.add_Hm();
  }

  DateFormat add_Hms(DateFormat format) {
    var isFreedomUnit = _settingService.readBool(timeMode);

    return isFreedomUnit ? format.add_jms() : format.add_Hms();
  }
}
