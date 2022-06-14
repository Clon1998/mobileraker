import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/ui/components/dialog/excludeObject/exclude_objects_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:touchable/touchable.dart';
import 'package:vector_math/vector_math.dart' as vec;

class ExcludeObjectDialog
    extends ViewModelBuilderWidget<ExcludeObjectViewModel> {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  ExcludeObjectDialog(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget builder(
      BuildContext context, ExcludeObjectViewModel model, Widget? child) {
    var themeData = Theme.of(context);
    return FormBuilder(
        autoFocusOnValidationFailure: true,
        key: model.formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Dialog(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: (model.dataReady)
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Exclude Object from Print',
                      style: themeData.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    Divider(),
                    AspectRatio(
                      aspectRatio: 1,
                      child: CanvasTouchDetector(
                          gesturesToOverride: [
                            GestureType.onTapDown,
                            GestureType.onTapUp
                          ],
                          builder: (context) =>
                              CustomPaint(painter: ExcludeObjectPainter(context, model))),
                    ),
                    FormBuilderDropdown<ParsedObject?>(
                      initialValue: null,
                      name: 'selected',
                      items: model.excludeObject.objects
                          .map((parsedObj) => DropdownMenuItem(
                              value: parsedObj,
                              child: Text('${parsedObj.name}')))
                          .toList(),
                      onChanged: model.onSelectedObjectChanged,
                      decoration: InputDecoration(
                        labelText: 'Object to exclude',
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton(
                          onPressed: model.onCancelPressed,
                          child: Text(MaterialLocalizations.of(context)
                              .cancelButtonLabel),
                        )
                      ],
                    )
                  ],
                )
              : Text('Waiting for data...'),
        )));
  }

  @override
  ExcludeObjectViewModel viewModelBuilder(BuildContext context) {
    return ExcludeObjectViewModel(request, completer);
  }
}

class ExcludeObjectPainter extends CustomPainter {
  final BuildContext context;
  final ExcludeObjectViewModel model;

  ExcludeObjectPainter(this.context, this.model) : this.obj = model.selectedObject;

  double maxXBed = 300;
  double maxYBed = 300;

  ParsedObject? obj;

  @override
  void paint(Canvas canvas, Size size) {
    TouchyCanvas myCanvas = TouchyCanvas(context, canvas);

    var paintBg = Paint()
      ..color = Theme.of(context).colorScheme.onBackground
      ..strokeWidth = 2;

    Paint paintSelected = Paint()
      ..color = Theme.of(context).colorScheme.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    double maxX = size.width;
    double maxY = size.height;

    for (int i = 1; i < 4; i++) {
      myCanvas.drawLine(
          Offset(maxX * 0.25 * i, 0), Offset(maxX * 0.25 * i, maxY), paintBg);
      myCanvas.drawLine(
          Offset(0, maxY * 0.25 * i), Offset(maxX, maxY * 0.25 * i), paintBg);
    }

    for (ParsedObject obj in model.excludeObject.objects) {
      List<vec.Vector2> polygons = obj.polygons;
      if (polygons.isEmpty) continue;

      Path path = constructPath(polygons, maxX, maxY);

      myCanvas.drawPath(path, paintBg,
          onTapDown: (x) => model.onPathTapped(obj));
      if (model.selectedObject == obj) myCanvas.drawPath(path, paintSelected);
    }
  }

  double correctY(double y) => 300 - y;

  Path constructPath(List<vec.Vector2> polygons, double maxX, double maxY) {
    var path = Path();
    vec.Vector2 start = polygons.first;
    path.moveTo(start.x / maxXBed * maxX, correctY(start.y) / maxYBed * maxY);
    for (vec.Vector2 poly in polygons) {
      path.lineTo(poly.x / maxXBed * maxX, correctY(poly.y) / maxYBed * maxY);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return obj != model.selectedObject;
  }
}
