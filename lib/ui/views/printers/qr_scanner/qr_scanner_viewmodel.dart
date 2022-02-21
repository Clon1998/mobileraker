import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class QrScannerViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  bool _barcodeRead = false;

  onBarCode(Barcode barcode) {
    if (_barcodeRead) return;
    _barcodeRead = true;
    _navigationService.back(result: barcode.rawValue);
  }
}
