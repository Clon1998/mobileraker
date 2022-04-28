import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/dto/files/remote_file.dart';
import 'package:mobileraker/ui/views/files/details/config_file_details_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

class ConfigFileDetailView
    extends ViewModelBuilderWidget<ConfigFileDetailsViewModel> {
  const ConfigFileDetailView({Key? key, required this.file}) : super(key: key);
  final RemoteFile file;

  @override
  Widget builder(
      BuildContext context, ConfigFileDetailsViewModel model, Widget? child) {
    final ThemeData themeData = Theme.of(context);
    return Scaffold(
      backgroundColor: model.codeController.theme?['root']?.backgroundColor,
      appBar: AppBar(
        title: Text(
          file.name,
          overflow: TextOverflow.fade,
        ),
        actions: [
          // IconButton(onPressed: null, icon: Icon(Icons.live_help_outlined)),
          // IconButton(onPressed: null, icon: Icon(Icons.search))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: (model.dataReady)
                ? SingleChildScrollView(
                    child: Column(
                      children: [
                        CodeField(
                          controller: model.codeController,
                          enabled: !model.isUploading,
                          // expands: true,
                          // wrap: true,
                        ),
                        SizedBox(
                          height: 30,
                        )
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitRipple(
                          color: themeData.colorScheme.secondary,
                          size: 100,
                        ),
                        SizedBox(
                          height: 30,
                        ),
                        FadingText('Downloading file ${file.name}'),
                        // Text('Fetching printer ...')
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: (model.dataReady)
          ? SpeedDial(
              backgroundColor:
                  (model.isUploading) ? Theme.of(context).disabledColor : null,
              icon: FlutterIcons.save_mdi,
              activeIcon: model.isUploading ? null : Icons.close,
              children: [
                SpeedDialChild(
                  child: Icon(Icons.save),
                  backgroundColor: themeData.colorScheme.primaryContainer,
                  label: 'Save',
                  onTap: (model.isUploading) ? null : model.onSaveTapped,
                  visible: !model.isUploading,
                ),
                SpeedDialChild(
                  child: Icon(Icons.restart_alt),
                  backgroundColor: themeData.colorScheme.primary,
                  label: 'Save & Restart',
                  onTap: (model.isUploading) ? null : model.onSaveAndRestartTapped,
                  visible: !model.isUploading,
                ),
              ],
              spacing: 5,
              overlayOpacity: 0.5,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }

  Widget buildBreadCrumb(BuildContext context) {
    List<String> paths = file.parentPath.split('/');
    paths.add(file.name);
    ThemeData theme = Theme.of(context);
    Color highlightColor = theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: highlightColor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: BreadCrumb.builder(
                itemCount: paths.length,
                builder: (index) {
                  String p = paths[index];
                  return BreadCrumbItem(
                    content: Text(
                      '${p.toUpperCase()}',
                      style: theme.textTheme.subtitle1
                          ?.copyWith(color: theme.colorScheme.onPrimary),
                    ),
                  );
                },
                divider: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '/',
                    style: theme.textTheme.subtitle1
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  ConfigFileDetailsViewModel viewModelBuilder(BuildContext context) =>
      ConfigFileDetailsViewModel(file);
}
