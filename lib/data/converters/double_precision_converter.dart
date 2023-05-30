import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/util/extensions/double_extension.dart';

class Double1PrecisionConverter extends JsonConverter<double, double> {
  const Double1PrecisionConverter();

  @override
  double fromJson(double json) => json.toPrecision(1);

  @override
  double toJson(double object) => object;
}

class Double2PrecisionConverter extends JsonConverter<double, double> {
  const Double2PrecisionConverter();

  @override
  double fromJson(double json) => json.toPrecision(2);

  @override
  double toJson(double object) => object;
}

class Double3PrecisionConverter extends JsonConverter<double, double> {
  const Double3PrecisionConverter();

  @override
  double fromJson(double json) => json.toPrecision(3);

  @override
  double toJson(double object) => object;
}
