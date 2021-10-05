class ConfigPrinter {
  late final String kinematics;
  late final double maxVelocity;
  late final double maxAccel;
  late final double maxAccelToDecel;
  late final double squareCornerVelocity;

  ConfigPrinter.parse(Map<String, dynamic> json) {
    kinematics = json['kinematics'];
    maxVelocity = json['max_velocity'];
    maxAccel = json['max_accel'];
    maxAccelToDecel = json['max_accel_to_decel'] ?? maxAccel / 2;
    squareCornerVelocity = json['square_corner_velocity'] ?? 5;
  }
}
