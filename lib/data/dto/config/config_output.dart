class ConfigOutput {
  final String name;
  late double scale;
  late bool pwm;
  ConfigOutput.parse(this.name, Map<String, dynamic> json) {
    scale = json['scale']?? 1;
    pwm = json['pwm']??false;
  }
}