import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/ui/components/dialog/exclude_object/exclude_objects_viewmodel.dart';
import 'package:mobileraker/ui/themes/theme_pack.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:stringr/stringr.dart';
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
    ThemeData themeData = Theme.of(context);
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
                      'dialogs.exclude_object.title',
                      style: themeData.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ).tr(),
                    Divider(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ExcludeObject(),
                    ),
                    if (model.confirmed)
                      ListTile(
                        tileColor: themeData.colorScheme.errorContainer,
                        textColor: themeData.colorScheme.onErrorContainer,
                        iconColor: themeData.colorScheme.onErrorContainer,
                        leading: Icon(
                          Icons.warning_amber_outlined,
                          size: 40,
                        ),
                        title: Text(
                          'dialogs.exclude_object.confirm_tile_title',
                        ).tr(),
                        subtitle:
                            Text('dialogs.exclude_object.confirm_tile_subtitle')
                                .tr(),
                      ),
                    FormBuilderDropdown<ParsedObject?>(
                      initialValue: null,
                      enabled: !model.confirmed,
                      validator: FormBuilderValidators.compose(
                          [FormBuilderValidators.required()]),
                      name: 'selected',
                      items: model.excludeObject.canBeExcluded
                          .map((parsedObj) => DropdownMenuItem(
                              value: parsedObj,
                              child: Text('${parsedObj.name}')))
                          .toList(),
                      onChanged: model.onSelectedObjectChanged,
                      decoration: InputDecoration(
                        labelText: 'dialogs.exclude_object.label'.tr(),
                      ),
                    ),
                    (model.confirmed) ? ExcludeBtnRow() : DefaultBtnRow()
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

class DefaultBtnRow extends ViewModelWidget<ExcludeObjectViewModel> {
  const DefaultBtnRow({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ExcludeObjectViewModel model) {
    ThemeData themeData = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: model.closeForm,
          child: Text(MaterialLocalizations.of(context)
              .cancelButtonLabel
              .toLowerCase()
              .titleCase()),
        ),
        TextButton(
          onPressed: (model.formValid && model.canExclude)
              ? model.onExcludePressed
              : null,
          child: Text('dialogs.exclude_object.exclude').tr(),
        )
      ],
    );
  }
}

class ExcludeBtnRow extends ViewModelWidget<ExcludeObjectViewModel> {
  const ExcludeBtnRow({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ExcludeObjectViewModel model) {
    ThemeData themeData = Theme.of(context);
    CustomColors? customColors = themeData.extension<CustomColors>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: model.onBackPressed,
          child: Text(MaterialLocalizations.of(context).backButtonTooltip),
        ),
        TextButton(
          onPressed: model.onCofirmPressed,
          child: Text(
            'general.confirm',
            style: TextStyle(color: customColors?.danger),
          ).tr(),
        )
      ],
    );
  }
}

class ExcludeObject extends ViewModelWidget<ExcludeObjectViewModel> {
  const ExcludeObject({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ExcludeObjectViewModel model) {
    return AspectRatio(
      aspectRatio: model.sizeX / model.sizeY,
      child: CanvasTouchDetector(
          gesturesToOverride: [GestureType.onTapDown, GestureType.onTapUp],
          builder: (context) =>
              CustomPaint(painter: ExcludeObjectPainter(context, model))),
    );
  }
}

class ExcludeObjectPainter extends CustomPainter {
  static const double bgLineDis = 50;

  final BuildContext context;
  final ExcludeObjectViewModel model;

  ExcludeObjectPainter(this.context, this.model)
      : this.obj = model.selectedObject;

  double get _maxXBed => model.sizeX;

  double get _maxYBed => model.sizeY;

  ParsedObject? obj;

  @override
  void paint(Canvas canvas, Size size) {
    TouchyCanvas myCanvas = TouchyCanvas(context, canvas);

    var paintBg = Paint()
      ..color = Theme.of(context).colorScheme.onSurface.darken(60)
      ..strokeWidth = 2;

    var paintObj = Paint()
      ..color = Theme.of(context).colorScheme.onSurface
      ..strokeWidth = 2;
    var paintObjExcluded = Paint()
      ..color = Theme.of(context).colorScheme.onSurface.darken(35)
      ..strokeWidth = 2;

    Paint paintSelected = Paint()
      ..color = Theme.of(context).colorScheme.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    double maxX = size.width;
    double maxY = size.height;

    drawXLines(maxX, myCanvas, maxY, paintBg);
    drawYLines(maxY, myCanvas, maxX, paintBg);

    bool tmp = false;
    for (ParsedObject obj in model.excludeObject.objects) {
      List<vec.Vector2> polygons = obj.polygons;
      if (polygons.isEmpty) continue;
      tmp = true;
      Path path = constructPath(polygons, maxX, maxY);

      if (model.excludeObject.excludedObjects.contains(obj.name)) {
        myCanvas.drawPath(path, paintObjExcluded);
      } else {
        myCanvas.drawPath(path, paintObj,
            onTapDown: (x) => model.onPathTapped(obj));
        if (model.selectedObject == obj) myCanvas.drawPath(path, paintSelected);
      }
    }
    if (!tmp) drawNoDataText(canvas, maxX, maxY);
  }

  void drawNoDataText(Canvas canvas, double maxX, double maxY) {
    TextSpan span = new TextSpan(
      text: 'dialogs.exclude_object.no_visualization'.tr(),
      style: Theme.of(context).textTheme.headline4,
    );
    TextPainter tp = new TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout(
      minWidth: 0,
      maxWidth: maxX,
    );
    tp.paint(canvas, Offset((maxX - tp.width) / 2, (maxY - tp.height) / 2));
  }

  void drawYLines(
      double maxY, TouchyCanvas myCanvas, double maxX, Paint paintBg) {
    for (int i = 1; i < _maxYBed ~/ bgLineDis; i++) {
      var y = (bgLineDis * i) / _maxYBed * maxY;
      myCanvas.drawLine(Offset(0, y), Offset(maxX, y), paintBg);
    }
  }

  void drawXLines(
      double maxX, TouchyCanvas myCanvas, double maxY, Paint paintBg) {
    for (int i = 1; i < _maxXBed ~/ bgLineDis; i++) {
      var x = (bgLineDis * i) / _maxXBed * maxX;
      myCanvas.drawLine(Offset(x, 0), Offset(x, maxY), paintBg);
    }
  }

  double correctY(double y) => _maxYBed - y;

  Path constructPath(List<vec.Vector2> polygons, double maxX, double maxY) {
    var path = Path();
    vec.Vector2 start = polygons.first;
    path.moveTo(start.x / _maxXBed * maxX, correctY(start.y) / _maxYBed * maxY);
    for (vec.Vector2 poly in polygons) {
      path.lineTo(poly.x / _maxXBed * maxX, correctY(poly.y) / _maxYBed * maxY);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return obj != model.selectedObject;
  }
}
