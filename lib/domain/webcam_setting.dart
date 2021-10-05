import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'webcam_setting.g.dart';

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebcamSetting &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          uuid == other.uuid &&
          url == other.url &&
          flipHorizontal == other.flipHorizontal &&
          flipVertical == other.flipVertical;

  @override
  int get hashCode =>
      name.hashCode ^
      uuid.hashCode ^
      url.hashCode ^
      flipHorizontal.hashCode ^
      flipVertical.hashCode;
}
