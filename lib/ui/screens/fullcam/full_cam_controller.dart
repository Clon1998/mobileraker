import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'full_cam_controller.g.dart';

@Riverpod(dependencies: [])
Machine fullCamMachine(FullCamMachineRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [])
WebcamInfo initialCam(InitialCamRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [fullCamMachine, initialCam])
class FullCamPageController extends _$FullCamPageController {
  @override
  WebcamInfo build() {
    return ref.watch(initialCamProvider);
  }

  selectCam(WebcamInfo? cam) {
    if (cam == null) return;
    state = cam;
  }
}
