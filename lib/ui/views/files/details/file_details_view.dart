import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/dto/files/gcode_file.dart';
import 'package:mobileraker/ui/views/files/details/file_details_viewmodel.dart';
import 'package:mobileraker/util/time_util.dart';
import 'package:stacked/stacked.dart';

class FileDetailView extends ViewModelBuilderWidget<FileDetailsViewModel> {
  const FileDetailView({Key? key, required this.file}) : super(key: key);
  final GCodeFile file;

  @override
  Widget builder(
      BuildContext context, FileDetailsViewModel model, Widget? child) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          file.name,
          overflow: TextOverflow.fade,
        ),
      ),
      body: Column(children: [
        CachedNetworkImage(
          imageUrl:
              '${model.curPathToPrinterUrl}/${file.parentPath}/${file.bigImagePath}',
          imageBuilder: (context, imageProvider) => Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
              Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: const Radius.circular(8.0)),
                    color: Theme.of(context)
                        .colorScheme
                        .primaryVariant
                        .withOpacity(0.8),
                  ),
                  child: Text(
                    file.name,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5,
                    style: Theme.of(context)
                        .textTheme
                        .subtitle2
                        ?.copyWith(color: Colors.white),
                  ))
            ],
          ),
          placeholder: (context, url) => Icon(Icons.insert_drive_file),
          errorWidget: (context, url, error) => Column(
            children: [
              Icon(Icons.file_present),
              Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.vertical(top: const Radius.circular(8.0)),
                    color: Theme.of(context)
                        .colorScheme
                        .primaryVariant
                        .withOpacity(0.8),
                  ),
                  child: Text(
                    file.name,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5,
                    style: Theme.of(context)
                        .textTheme
                        .subtitle2
                        ?.copyWith(color: Colors.white),
                  ))
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Table(
            border: TableBorder(
                horizontalInside: BorderSide(
                    width: 1,
                    color: Theme.of(context).dividerColor,
                    style: BorderStyle.solid)),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(5),
            },
            children: [
              TableRow(children: [
                Text('Path'),
                Text('${file.parentPath}/${file.name}'),
              ]),
              TableRow(children: [
                Text('Last modified'),
                Text(model.formattedLastModified),
              ]),
              TableRow(children: [
                Text('Last printed'),
                Text((file.printStartTime != null)
                    ? model.formattedLastPrinted
                    : 'No Data'),
              ]),
              TableRow(children: [
                Text('Slicer'),
                Text('${file.slicer} (v${file.slicerVersion})'),
              ]),
              TableRow(children: [
                Text('Layer Height'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Normal"),
                        Text('${file.layerHeight?.toStringAsFixed(2)} mm'),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("First"),
                        Text('${file.firstLayerHeight?.toStringAsFixed(2)} mm'),
                      ],
                    ),
                  ],
                ),
              ]),
              TableRow(children: [
                Text('First Layer Temps'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Extruder"),
                        Text(
                            '${file.firstLayerTempExtruder?.toStringAsFixed(0)}°C'),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Bed"),
                        Text('${file.firstLayerTempBed?.toStringAsFixed(0)}°C'),
                      ],
                    ),
                  ],
                ),
              ]),
              if (file.estimatedTime != null)
              TableRow(children: [
                Text('Est. print time'),
                Text(
                    '${secondsToDurationText(file.estimatedTime ?? 0)} (ETA: ${model.potentialEta})'),
              ]),
            ],
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor:
            (model.canStartPrint) ? null : Theme.of(context).disabledColor,
        onPressed: (model.canStartPrint) ? model.onStartPrintTap : null,
        icon: Icon(FlutterIcons.printer_3d_nozzle_mco),
        label: Text("Print"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  FileDetailsViewModel viewModelBuilder(BuildContext context) =>
      FileDetailsViewModel(file);
}
