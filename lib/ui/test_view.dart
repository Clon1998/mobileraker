import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:stacked/stacked.dart';

class TestView extends StatelessWidget {
  const TestView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TestViewModel>.reactive(
      builder: (context, model, child) => Scaffold(
        appBar: AppBar(
          title: Text("Example player"),
        ),
        // body: Mjpeg(
        //   stream: 'http://192.168.178.135/webcam/?action=stream',
        // )

        body: Transform.rotate(
            angle: pi,
            child: Mjpeg(
              isLive: true,
              stream: 'http://192.168.178.135/webcam/?action=stream',
            )),
      ),
      viewModelBuilder: () => TestViewModel(),
    );
  }
}

class TestViewModel extends BaseViewModel {}
