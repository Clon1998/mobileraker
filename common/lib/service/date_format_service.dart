/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'date_format_service.g.dart';

@Riverpod(keepAlive: true)
DateFormatService dateFormatService(Ref ref) {
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

  DateFormat s() {
    return DateFormat.s();
  }

  DateFormat ms() {
    return DateFormat.ms();
  }

  DateFormat add_Hm(DateFormat format, [String seperator = ' ']) {
    var isFreedomUnit = _settingService.readBool(AppSettingKeys.timeFormat);
    return isFreedomUnit ? format.addPattern('jm', seperator) : format.addPattern('Hm', seperator);
  }

  DateFormat add_Hms(DateFormat format) {
    var isFreedomUnit = _settingService.readBool(AppSettingKeys.timeFormat);

    return isFreedomUnit ? format.add_jms() : format.add_Hms();
  }

  String Function(DateTime) formatRelativeHm() {
    return _formatRelativeHm;
  }

  String _formatRelativeHm(DateTime target) {
    final hm = Hm();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    if (target.day == today.day && target.month == today.month && target.year == today.year) {
      return '${tr('date.reference.today')}, ${hm.format(target)}';
    } else if (target.day == yesterday.day && target.month == yesterday.month && target.year == yesterday.year) {
      return '${tr('date.reference.yesterday')} ${hm.format(target)}';
    } else if (target.day == tomorrow.day && target.month == tomorrow.month && target.year == tomorrow.year) {
      return '${tr('date.reference.tomorrow')} ${hm.format(target)}';
    } else {
      return add_Hm(DateFormat.yMMMd(), ', ').format(target);
    }
  }
}
