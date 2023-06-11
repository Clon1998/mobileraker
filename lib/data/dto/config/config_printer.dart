/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

class ConfigPrinter {
  final String kinematics;
  final double maxVelocity;
  final double maxAccel;
  final double maxAccelToDecel;
  final double squareCornerVelocity;

  ConfigPrinter.parse(Map<String, dynamic> json)
      : kinematics = json['kinematics'],
        maxVelocity = json['max_velocity'],
        maxAccel = json['max_accel'],
        maxAccelToDecel = json['max_accel_to_decel'] ?? json['max_accel'] / 2,
        squareCornerVelocity = json['square_corner_velocity'] ?? 5;
}
