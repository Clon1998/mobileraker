/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/eta_data_source.dart';
import 'package:common/service/setting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'setting_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> settingPageFormKey(SettingPageFormKeyRef _) => GlobalKey<FormBuilderState>();

@riverpod
class SettingPageController extends _$SettingPageController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  @override
  void build() {
    return;
  }

  Future<void> openCompanion() async {
    const String url = 'https://github.com/Clon1998/mobileraker_companion#companion---installation';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> onEtaSourcesChanged(List<ETADataSource>? sources) async {
    if (sources == null) {
      return;
    }
    if (sources.isEmpty) {
      return; // We don't want to save an empty list
    }

    _settingService.writeList(AppSettingKeys.etaSources, sources, (e) => e.toJson());

  }
}
