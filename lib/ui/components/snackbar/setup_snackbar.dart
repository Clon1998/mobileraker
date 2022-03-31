import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/enums/snackbar_type.dart';
import 'package:stacked_services/stacked_services.dart';


void setupSnackbarUi() {
  final service = locator<SnackbarService>();

  // Registers a config to be used when calling showSnackbar
  service.registerSnackbarConfig(SnackbarConfig(
    titleColor: Colors.white,
    messageColor: Colors.white70,
  ));

  service.registerCustomSnackbarConfig(
      variant: SnackbarType.error,
      config: SnackbarConfig(
        backgroundColor: Colors.red
      ));
  service.registerCustomSnackbarConfig(
      variant: SnackbarType.warning,
      config: SnackbarConfig(
          backgroundColor: Colors.orange
      ));
}
