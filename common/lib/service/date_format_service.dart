/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'date_format_service.g.dart';

@Riverpod(keepAlive: true)
DateFormatService dateFormatService(DateFormatServiceRef ref) {
  var settingService = ref.watch(settingServiceProvider);
  return DateFormatService(settingService);
}

class DateFormatService {
  final SettingService _settingService;

  const DateFormatService(this._settingService);

  DateFormat _jm() => DateFormat('h:mm a');

  DateFormat _jms() => DateFormat('h:mm:ss a');

  DateFormat Hm() {
    var isFreedomUnit = _settingService.readBool(AppSettingKeys.timeFormat);

    return isFreedomUnit ? _jm() : DateFormat.Hm();
  }

  DateFormat Hms() {
    var isFreedomUnit = _settingService.readBool(AppSettingKeys.timeFormat);

    return isFreedomUnit ? _jms() : DateFormat.Hms();
  }

  DateFormat add_Hm(DateFormat format) {
    var isFreedomUnit = _settingService.readBool(AppSettingKeys.timeFormat);

    return isFreedomUnit ? format.add_jm() : format.add_Hm();
  }

  DateFormat add_Hms(DateFormat format) {
    var isFreedomUnit = _settingService.readBool(AppSettingKeys.timeFormat);

    return isFreedomUnit ? format.add_jms() : format.add_Hms();
  }
}
