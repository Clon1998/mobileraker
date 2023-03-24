import 'package:hive/hive.dart';

part 'webcam_rotation.g.dart';

@HiveType(typeId: 9)
enum WebCamRotation {
  @HiveField(0)
  landscape,
  @HiveField(1)
  portrait }
