import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/test/test_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

class TestView extends ViewModelBuilderWidget<TestViewModel> {
  @override
  Widget builder(BuildContext context, TestViewModel model, Widget? child) {

    print('3D Models: ${model.models3d.length}');

    return Scaffold(
        appBar: AppBar(
          title: const Text('3D-Viewer'),
        ),
        drawer: NavigationDrawerWidget(curPath: Routes.testView),
        body: Center(
            child: DiTreDiDraggable(
          controller: model.controller,
          child: DiTreDi(
            controller: model.controller,
            config: DiTreDiConfig(),
            figures: [
              PointPlane3D(300, Axis3D.y, 25, vec.Vector3(150, 0, 150),
                  pointWidth: 5),
              ...model.models3d
            ],
          ),
        )));
  }


  @override
  void onViewModelReady(TestViewModel viewModel) async {
    viewModel.parseGcode();
    print("onViewModelReady-parse done");
  }

  @override
  TestViewModel viewModelBuilder(BuildContext context) => TestViewModel();
}
