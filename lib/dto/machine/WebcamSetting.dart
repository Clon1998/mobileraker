import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'WebcamSetting.g.dart';

@HiveType(typeId: 2)
class WebcamSetting {
  @HiveField(0)
  String name;
  @HiveField(1)
  String uuid = Uuid().v4();
  @HiveField(2)
  String url;
  @HiveField(3)
  bool flipHorizontal = false;
  @HiveField(4)
  bool flipVertical = false;

  WebcamSetting(this.name, this.url);

  @override
  String toString() {
    return 'WebcamSetting{name: $name, uuid: $uuid, url: $url, flipHorizontal: $flipHorizontal, flipVertical: $flipVertical}';
  }
}
