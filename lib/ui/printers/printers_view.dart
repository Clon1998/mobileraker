import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/ui/printers/components/printers_slidable_view.dart';
import 'package:mobileraker/ui/printers/printers_viewmodel.dart';
import 'package:stacked/stacked.dart';

class Printers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PrintersViewModel>.reactive(
        builder: (context, model, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text("Printers"),
            ),
            body: getBody(model, context),
            floatingActionButton: FloatingActionButton(
              mini: true,
              tooltip: "Add Printer",
              child: Icon(Icons.add),
              onPressed: model.onAddPrinterPressed,
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.miniCenterFloat,
          );
        },
        viewModelBuilder: () => PrintersViewModel());
  }

  Widget getBody(PrintersViewModel model, BuildContext context) {
    var settings = model.fetchSettings();
    if (settings.isEmpty)
      return Center(
          child: Text(
        'Please add a Printer!',
        style: Theme.of(context).textTheme.headline5,
      ));

    return ListView.builder(
        itemCount: settings.length,
        itemBuilder: (context, index) {
          var cur = settings.elementAt(index);

          return PrintersSlidable(printerSetting: cur);
        });
  }
}
