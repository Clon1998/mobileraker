/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulHookConsumerWidget {
  const QrScannerPage({super.key});

  @override
  ConsumerState createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController();
  StreamSubscription<BarcodeCapture>? _streamSubscription;

  bool _scannedBarcode = false;

  @override
  void initState() {
    super.initState();
    _cameraController.start(cameraDirection: CameraFacing.back);
    _streamSubscription = _cameraController.barcodes.listen((event) {
      if (_scannedBarcode) return;
      _scannedBarcode = true;
      context.pop(event.barcodes.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    var torch = useListenableSelector(_cameraController, () => _cameraController.value.torchState);
    var facing = useListenableSelector(_cameraController, () => _cameraController.value.cameraDirection);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Scanner'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: switch (torch) {
              TorchState.on => const Icon(Icons.flash_on, color: Colors.yellow),
              _ => const Icon(Icons.flash_off, color: Colors.grey),
            },
            iconSize: 32.0,
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: switch (facing) {
              CameraFacing.front => const Icon(Icons.camera_front),
              CameraFacing.back => const Icon(Icons.camera_rear),
            },
            iconSize: 32.0,
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(controller: _cameraController),
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _cameraController.dispose();
    super.dispose();
  }
}
