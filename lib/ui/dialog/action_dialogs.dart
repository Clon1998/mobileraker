import 'package:stacked_services/stacked_services.dart';

Future<DialogResponse?> emergencyStopConfirmDialog(DialogService dialogService) {
  return dialogService.showConfirmationDialog(
    title: "Emergency Stop - Confirmation",
    description: "Are you sure?",
    confirmationTitle: "STOP!",
  );
}
