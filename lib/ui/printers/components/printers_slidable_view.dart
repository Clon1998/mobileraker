import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/ui/printers/components/printers_slidable_viewmodel.dart';
import 'package:stacked/stacked.dart';

class PrintersSlidable extends StatelessWidget {
  final PrinterSetting printerSetting;

  const PrintersSlidable({
    Key? key,
    required this.printerSetting,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PrintersSlidableViewModel>.reactive(builder: (context, model, child) {
      return Slidable(
        child: ListTile(
          selected: model.isSelectedPrinter,
          onLongPress: model.onSetActiveTap,
          title: Text(model.name),
          subtitle: Text(model.baseUrl),
          trailing: IconButton(
            icon: Icon(
              Icons.radio_button_on,
              size: 10,
              color: model.stateColor,
            ),
            tooltip: model.stateText,
            onPressed: () => null,
          ),
        ),
        actionPane: SlidableDrawerActionPane(),
        actions: [
          IconSlideAction(
            caption: 'Delete',
            icon: Icons.delete_forever,
            color: Colors.red,
            onTap: model.onDeleteTap,
          ),
          IconSlideAction(
            caption: 'Edit',
            icon: Icons.settings,
            color: Colors.blue,
            onTap: model.onEditTap,
          ),
        ],
        actionExtentRatio: 0.2,
      );
    }, viewModelBuilder: () => PrintersSlidableViewModel(printerSetting),);
  }
}
