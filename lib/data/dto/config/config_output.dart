class ConfigOutput {
  final String name;
  double scale;
  bool pwm;

  ConfigOutput.parse(this.name, Map<String, dynamic> json)
      : scale = json['scale'] ?? 1,
        pwm = json['pwm'] ?? false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigOutput &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          scale == other.scale &&
          pwm == other.pwm;

  @override
  int get hashCode => name.hashCode ^ scale.hashCode ^ pwm.hashCode;

  @override
  String toString() {
    return 'ConfigOutput{name: $name, scale: $scale, pwm: $pwm}';
  }
}
