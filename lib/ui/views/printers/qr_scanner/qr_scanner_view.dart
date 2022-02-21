import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/ui/views/printers/qr_scanner/qr_scanner_viewmodel.dart';
import 'package:stacked/stacked.dart';

class QrScannerView extends ViewModelBuilderWidget<QrScannerViewModel> {
  final MobileScannerController cameraController = MobileScannerController();

  @override
  QrScannerViewModel viewModelBuilder(BuildContext context) =>
      QrScannerViewModel();

  @override
  Widget builder(
      BuildContext context, QrScannerViewModel model, Widget? child) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Mobile Scanner'),
          actions: [
            IconButton(
              color: Colors.white,
              icon: ValueListenableBuilder(
                valueListenable: cameraController.torchState,
                builder: (context, state, child) {
                  switch (state as TorchState) {
                    case TorchState.off:
                      return const Icon(Icons.flash_off, color: Colors.grey);
                    case TorchState.on:
                      return const Icon(Icons.flash_on, color: Colors.yellow);
                  }
                },
              ),
              iconSize: 32.0,
              onPressed: () => cameraController.toggleTorch(),
            ),
            IconButton(
              color: Colors.white,
              icon: ValueListenableBuilder(
                valueListenable: cameraController.cameraFacingState,
                builder: (context, state, child) {
                  switch (state as CameraFacing) {
                    case CameraFacing.front:
                      return const Icon(Icons.camera_front);
                    case CameraFacing.back:
                      return const Icon(Icons.camera_rear);
                  }
                },
              ),
              iconSize: 32.0,
              onPressed: () => cameraController.switchCamera(),
            ),
          ],
        ),
        body: MobileScanner(
            controller: cameraController,
            onDetect: (barcode, args) => model.onBarCode(barcode)));
  }
}
