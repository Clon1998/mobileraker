import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/dto/files/folder.dart';
import 'package:mobileraker/dto/files/gcode_file.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/machine/printer_setting.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/file_service.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _FolderContentStreamKey = 'folderContent';
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

  StreamController<FolderReqWrapper> _foldersStream = StreamController();

  List<String> requestedPath = [];

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<PrinterSetting?>(_machineService.selectedPrinter),
        if (_fileService != null) ...{
          _FolderContentStreamKey:
              StreamData<FolderReqWrapper>(_foldersStream.stream)
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
      default:
        break;
    }
  }

  onRefresh() {
    runBusyFuture(
            _fetchDirectoryData(newPath: folderContent.reqPath.split('/')))
        .then((value) => refreshController.refreshCompleted());
  }

  onFileTapped(GCodeFile file) {
    _navigationService.navigateTo(Routes.fileDetailView,
        arguments: FileDetailViewArguments(file: file));
  }

  onFolderPressed(Folder folder) {
    List<String> newPath = folderContent.reqPath.split('/');
    newPath.add(folder.name);
    runBusyFuture(_fetchDirectoryData(newPath: newPath));
  }

  Future<bool> onWillPop() async {
    List<String> newPath = folderContent.reqPath.split('/');

    if (isSearching) {
      stopSearching();
      return false;
    } else if (newPath.length > 1 && !isBusy) {
      newPath.removeLast();
      runBusyFuture(_fetchDirectoryData(newPath: newPath));
      return false;
    }
    return true;
  }

  onPopFolder() async {
    List<String> newPath = folderContent.reqPath.split('/');
    if (newPath.length > 1 && !isBusy) {
      newPath.removeLast();
      runBusyFuture(_fetchDirectoryData(newPath: newPath));
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
    return _foldersStream.addStream(
        _fileService!.fetchDirectoryInfo(newPath.join('/'), true).asStream());
  }

  onSortSelected(int index) {
    selectedSorting = index;
  }

  FolderReqWrapper get folderContent {
    FolderReqWrapper fullContent = _folderContent;
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

    folders.sort(folderComparators[selectedSorting]);
    files.sort(fileComparators[selectedSorting]);

    return FolderReqWrapper(fullContent.reqPath, folders, files);
  }

  bool get hasFolderContent => dataReady(_FolderContentStreamKey);

  FolderReqWrapper get _folderContent => dataMap![_FolderContentStreamKey];

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
