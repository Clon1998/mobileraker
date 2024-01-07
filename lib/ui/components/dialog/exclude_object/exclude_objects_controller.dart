/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final dialogCompleter = Provider.autoDispose<DialogCompleter>((ref) => throw UnimplementedError());

final excludeObjectFormKey = Provider.autoDispose<GlobalKey<FormBuilderState>>(
  (ref) => GlobalKey<FormBuilderState>(),
);

final excludeObjectProvider = StreamProvider.autoDispose<ExcludeObject?>((ref) {
  return ref.watchAsSubject(printerSelectedProvider.selectAs((d) => d.excludeObject));
});

final conirmedProvider = StateProvider.autoDispose((ref) => false);

final excludeObjectControllerProvider =
    StateNotifierProvider.autoDispose<ExcludeObjectController, ParsedObject?>(
  (ref) => ExcludeObjectController(ref),
);

class ExcludeObjectController extends StateNotifier<ParsedObject?> {
  ExcludeObjectController(this.ref) : super(null) {
    late ProviderSubscription<AsyncValue<PrintState>> sub;
    sub = ref.listen(
      printerSelectedProvider.selectAs((data) => data.print.state),
      (previous, AsyncValue<PrintState> next) {
        next.whenData((state) {
          if (!const {PrintState.printing, PrintState.paused}.contains(state)) {
            closeForm();
            sub.close();
          }
        });
      },
    );
  }

  AutoDisposeRef ref;

  void onSelectedObjectChanged(ParsedObject? obj) {
    state = obj;
  }

  void onPathTapped(ParsedObject obj) {
    if (ref.read(conirmedProvider)) return;
    ref.read(excludeObjectFormKey).currentState!.fields['selected']!.didChange(obj);
  }

  onExcludePressed() {
    if (ref.read(excludeObjectFormKey).currentState?.saveAndValidate() == false) {
      return;
    }

    ref.read(conirmedProvider.notifier).state = true;
  }

  onCofirmPressed() {
    if (state != null) {
      ref.read(printerServiceSelectedProvider).excludeObject(state!);
    }

    closeForm();
  }

  closeForm() => ref.read(dialogCompleter)(DialogResponse(confirmed: false));
}

// class ExcludeObjectViewModel extends StreamViewModel<Printer> {
//   final DialogRequest request;
//
//   final Function(DialogResponse) completer;
//
//   final _selectedMachineService = locator<SelectedMachineService>();
//
//   Machine? _machine;
//
//   ParsedObject? selectedObject;
//
//   bool confirmed = false;
//
//   Printer get printer => data!;
//
//   PrinterService? get _printerService => _machine?.printerService;
//
//   ExcludeObject get excludeObject {
//     return printer.excludeObject;
//   }
//
//   double get maxX => printer.configFile.stepperX?.positionMax ?? 300;
//
//   double get minX => printer.configFile.stepperX?.positionMin ?? 0;
//
//   double get maxY => printer.configFile.stepperY?.positionMax ?? 300;
//
//   double get minY => printer.configFile.stepperY?.positionMin ?? 0;
//
//   double get sizeX => maxX + minX.abs();
//
//   double get sizeY => maxY + minY.abs();
//
//   bool get canExclude =>
//       excludeObject.objects.length - excludeObject.excludedObjects.length > 1;
//
//   ExcludeObjectViewModel(this.request, this.completer);
//
//   @override
//   Stream<Printer> get stream => _printerService!.printerStream;
//
//   @override
//   void onData(Printer? data) {
//     if (data == null) return;
//     // Close form if print finished!
//     if (data.print.state != PrintState.printing) closeForm();
//   }
//
//   void onPathTapped(ParsedObject obj) {
//     if (confirmed) return;
//     _fbKey.currentState?.fields['selected']!.didChange(obj);
//   }
// }
