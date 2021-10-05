import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/dto/files/folder.dart';
import 'package:mobileraker/dto/files/gcode_file.dart';
import 'package:mobileraker/dto/files/notification/file_list_changed_item.dart';
import 'package:mobileraker/dto/files/notification/file_list_changed_notification.dart';
import 'package:mobileraker/dto/files/notification/file_list_changed_source_item.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/file_service.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:mobileraker/util/path_utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _FolderContentStreamKey = 'folderContent';
const String _FileNotification = 'fileNotification';
const String _ServerStreamKey = 'server';
const String _PrinterStreamKey = 'printer';

class FilesViewModel extends MultipleStreamViewModel {
  final _logger = getLogger('FilesViewModel');

  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _machineService = locator<MachineService>();

  bool isSearching = false;

  int selectedSorting = 0;

  List<Comparator<Folder>?> folderComparators = [
    (folderA, folderB) => folderB.modified.compareTo(folderA.modified),
    (folderA, folderB) => folderA.name.compareTo(folderB.name),
    null,
  ];
  List<Comparator<GCodeFile>?> fileComparators = [
    (fileA, fileB) => fileB.modified.compareTo(fileA.modified),
    (fileA, fileB) => fileA.name.compareTo(fileB.name),
    (fileA, fileB) =>
        fileB.printStartTime?.compareTo(fileA.printStartTime ?? 0) ?? -1,
  ];

  PrinterSetting? _printerSetting;

  FileService? get _fileService => _printerSetting?.fileService;

  PrinterService? get _printerService => _printerSetting?.printerService;

  KlippyService? get _klippyService => _printerSetting?.klippyService;

  RefreshController refreshController =
      RefreshController(initialRefresh: false);

  TextEditingController searchEditingController = TextEditingController();

  StreamController<FolderContentWrapper> _folderContentStreamController =
      StreamController();

  List<String> requestedPath = [];

  String get requestedPathAsString => requestedPath.join('/');

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<PrinterSetting?>(_machineService.selectedPrinter),
        if (_fileService != null) ...{
          _FolderContentStreamKey: StreamData<FolderContentWrapper>(
              _folderContentStreamController.stream)
        },
        if (_fileService != null) ...{
          _FileNotification: StreamData<FileListChangedNotification>(
              _fileService!.fileNotificationStream)
        },
        if (_printerService != null) ...{
          _PrinterStreamKey: StreamData<Printer>(_printerService!.printerStream)
        },
        if (_klippyService != null) ...{
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream)
        }
      };

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _SelectedPrinterStreamKey:
        PrinterSetting? nPrinterSetting = data;
        if (nPrinterSetting == _printerSetting) break;
        _printerSetting = nPrinterSetting;
        _fetchDirectoryData();
        notifySourceChanged(clearOldData: true);
        break;
      case _FileNotification:
        handleFileListChanged(data);
        break;

      default:
        break;
    }
  }

  void handleFileListChanged(
      FileListChangedNotification fileListChangedNotification) {
    _logger.i('CrntPath: $requestedPathAsString');
    _logger.i('$fileListChangedNotification');

    FileListChangedItem item = fileListChangedNotification.item;
    bool itemInParent = isWithin(requestedPathAsString, item.fullPath) == 0;

    FileListChangedSourceItem? srcItem = fileListChangedNotification.sourceItem;
    bool srcInParent = (srcItem != null)? isWithin(requestedPathAsString, srcItem.fullPath) == 0: false;

    if (!itemInParent && !srcInParent) {
      return;
    }

    _busyFetchDirectoryData(newPath: requestedPath);
  }

  onRefresh() {
    _busyFetchDirectoryData(newPath: folderContent.reqPath.split('/'))
        .then((value) => refreshController.refreshCompleted());
  }

  onFileTapped(GCodeFile file) {
    _navigationService.navigateTo(Routes.fileDetailView,
        arguments: FileDetailViewArguments(file: file));
  }

  onFolderPressed(Folder folder) {
    List<String> newPath = folderContent.reqPath.split('/');
    newPath.add(folder.name);
    _busyFetchDirectoryData(newPath: newPath);
  }

  Future<bool> onWillPop() async {
    List<String> newPath = folderContent.reqPath.split('/');

    if (isSearching) {
      stopSearching();
      return false;
    } else if (newPath.length > 1 && !isBusy) {
      newPath.removeLast();
      _busyFetchDirectoryData(newPath: newPath);
      return false;
    }
    return true;
  }

  onPopFolder() async {
    List<String> newPath = folderContent.reqPath.split('/');
    if (newPath.length > 1 && !isBusy) {
      newPath.removeLast();
      _busyFetchDirectoryData(newPath: newPath);
      return false;
    }
    return true;
  }

  startSearching() {
    isSearching = true;
  }

  stopSearching() {
    isSearching = false;
  }

  resetSearchQuery() {
    searchEditingController.text = '';
  }

  Future _fetchDirectoryData({List<String> newPath = const ['gcodes']}) {
    requestedPath = newPath;
    return _folderContentStreamController.addStream(_fileService!
        .fetchDirectoryInfo(requestedPathAsString, true)
        .asStream());
  }

  Future _busyFetchDirectoryData({List<String> newPath = const ['gcodes']}) {
    return runBusyFuture(_fetchDirectoryData(newPath: newPath));
  }

  onSortSelected(int index) {
    selectedSorting = index;
  }

  FolderContentWrapper get folderContent {
    FolderContentWrapper fullContent = _folderContent;
    List<Folder> folders = _folderContent.folders.toList(growable: false);
    List<GCodeFile> files = _folderContent.gCodes.toList(growable: false);

    String queryTerm = searchEditingController.text.toLowerCase();
    if (queryTerm.isNotEmpty && isSearching) {
      folders = folders
          .where((element) => element.name.toLowerCase().contains(queryTerm))
          .toList(growable: false);

      files = files
          .where((element) => element.name.toLowerCase().contains(queryTerm))
          .toList(growable: false);
    }
    var folderComparator = folderComparators[selectedSorting];
    if (folderComparator != null) folders.sort(folderComparator);
    files.sort(fileComparators[selectedSorting]);

    return FolderContentWrapper(fullContent.reqPath, folders, files);
  }

  bool get hasFolderContent => dataReady(_FolderContentStreamKey);

  FolderContentWrapper get _folderContent => dataMap![_FolderContentStreamKey];

  bool get hasServer => dataReady(_ServerStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isPrinterSelected => dataReady(_SelectedPrinterStreamKey);

  PrinterSetting? get selectedPrinter => dataMap?[_SelectedPrinterStreamKey];

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get hasPrinter => dataReady(_PrinterStreamKey);

  bool get isSubFolder => folderContent.reqPath.split('/').length > 1;

  String? get curPathToPrinterUrl {
    if (_printerSetting != null) {
      return '${_printerSetting!.httpUrl}/server/files';
    }
  }

  @override
  void dispose() {
    super.dispose();
    refreshController.dispose();
    searchEditingController.dispose();
  }
}
