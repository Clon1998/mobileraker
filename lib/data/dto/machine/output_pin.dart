class OutputPin {
  String name;

  // This value is between 0-1
  double value = 0.0;

  OutputPin(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutputPin &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value;

  @override
  int get hashCode => name.hashCode ^ value.hashCode;
}
