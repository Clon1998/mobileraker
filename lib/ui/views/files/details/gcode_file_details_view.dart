import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/ui/views/files/details/gcode_file_details_viewmodel.dart';
import 'package:mobileraker/util/time_util.dart';
import 'package:stacked/stacked.dart';

class GCodeFileDetailView
    extends ViewModelBuilderWidget<GCodeFileDetailsViewModel> {
  const GCodeFileDetailView({Key? key, required this.gcodeFile})
      : super(key: key);
  final GCodeFile gcodeFile;

  @override
  Widget builder(
      BuildContext context, GCodeFileDetailsViewModel model, Widget? child) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     file.name,
      //     overflow: TextOverflow.fade,
      //   ),
      // ),
      body: CustomScrollView(
        slivers: [
          SliverLayoutBuilder(builder: (context, constraints) {
            return SliverAppBar(
              expandedHeight: 220,
              floating: true,
              actions: [
                IconButton(
                  onPressed: model.preHeatAvailable && model.canStartPrint
                      ? model.preHeatPrinter
                      : null,
                  icon: Icon(
                    FlutterIcons.fire_alt_faw5s,
                  ),
                  tooltip: 'pages.files.details.preheat'.tr(),
                )
              ],
              // title: Text(
              //   file.name,
              //   overflow: TextOverflow.fade,
              //   maxLines: 1,
              // ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Hero(
                  tag: 'gCodeImage-${gcodeFile.hashCode}',
                  child: CachedNetworkImage(
                    imageUrl:
                        '${model.curPathToPrinterUrl}/${gcodeFile.parentPath}/${gcodeFile.bigImagePath}',
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                  top: const Radius.circular(8.0)),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.8),
                            ),
                            child: Text(
                              gcodeFile.name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 5,
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle2
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer),
                            ))
                      ],
                    ),
                    placeholder: (context, url) =>
                        Icon(Icons.insert_drive_file),
                    errorWidget: (context, url, error) => Column(
                      children: [
                        Expanded(child: Icon(Icons.file_present)),
                        Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                  top: const Radius.circular(8.0)),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.8),
                            ),
                            child: Text(
                              gcodeFile.name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 5,
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle2
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer),
                            ))
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          SliverToBoxAdapter(
            child: Column(children: [
              Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
                      title: Text('pages.setting.general.title').tr(),
                    ),
                    Divider(),
                    PropertyTile(
                        title: 'pages.files.details.general_card.path'.tr(),
                        subtitle: gcodeFile.absolutPath),
                    PropertyTile(
                      title: 'pages.files.details.general_card.last_mod'.tr(),
                      subtitle: model.formattedLastModified,
                    ),
                    PropertyTile(
                      title:
                          'pages.files.details.general_card.last_printed'.tr(),
                      subtitle: (gcodeFile.printStartTime != null)
                          ? model.formattedLastPrinted
                          : 'pages.files.details.general_card.no_data'.tr(),
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: Icon(FlutterIcons.tags_ant),
                      title: Text('pages.files.details.meta_card.title').tr(),
                    ),
                    Divider(),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.filament'.tr(),
                      subtitle:
                          '${tr('pages.files.details.meta_card.filament_type')}: ${gcodeFile.filamentType ?? tr('general.unknown')}\n'
                          '${tr('pages.files.details.meta_card.filament_name')}: ${gcodeFile.filamentName ?? tr('general.unknown')}',
                    ),
                    PropertyTile(
                      title:
                          'pages.files.details.meta_card.est_print_time'.tr(),
                      subtitle:
                          '${secondsToDurationText(gcodeFile.estimatedTime ?? 0)}, ${tr('pages.dashboard.general.print_card.eta')}: ${model.potentialEta}',
                    ),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.slicer'.tr(),
                      subtitle: model.usedSlicerAndVersion,
                    ),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.nozzle_diameter'.tr(),
                      subtitle:
                          '${gcodeFile.nozzleDiameter} mm',
                    ),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.layer_higher'.tr(),
                      subtitle:
                          '${tr('pages.files.details.meta_card.first_layer')}: ${gcodeFile.firstLayerHeight?.toStringAsFixed(2)} mm\n'
                          '${tr('pages.files.details.meta_card.others')}: ${gcodeFile.layerHeight?.toStringAsFixed(2)} mm',
                    ),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.first_layer_temps'
                          .tr(),
                      subtitle:
                          'pages.files.details.meta_card.first_layer_temps_value'
                              .tr(args: [
                        gcodeFile.firstLayerTempExtruder?.toStringAsFixed(0) ??
                            'general.unknown'.tr(),
                        gcodeFile.firstLayerTempBed?.toStringAsFixed(0) ??
                            'general.unknown'.tr()
                      ]),
                    ),
                  ],
                ),
              ),
              // Card(
              //   child: Column(
              //     mainAxisSize: MainAxisSize.min,
              //     children: <Widget>[
              //       ListTile(
              //         leading: Icon(FlutterIcons.chart_bar_mco),
              //         title: Text('pages.files.details.stat_card.title').tr(),
              //       ),
              //       Divider(),
              //       Placeholder(
              //
              //       )
              //     ],
              //   ),
              // ),
              SizedBox(
                height: 100,
              )
            ]),
          )
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor:
            (model.canStartPrint) ? null : Theme.of(context).disabledColor,
        onPressed: (model.canStartPrint) ? model.onStartPrintTap : null,
        icon: Icon(FlutterIcons.printer_3d_nozzle_mco),
        label: Text('pages.files.details.print').tr(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  GCodeFileDetailsViewModel viewModelBuilder(BuildContext context) =>
      GCodeFileDetailsViewModel(gcodeFile);
}

class PropertyTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const PropertyTile({Key? key, required this.title, required this.subtitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var subtitleTheme = textTheme.bodyText2
        ?.copyWith(fontSize: 13, color: textTheme.caption?.color);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.left,
          ),
          SizedBox(
            height: 2,
          ),
          Text(
            subtitle,
            style: subtitleTheme,
            textAlign: TextAlign.left,
          )
        ],
      ),
    );
  }
}
