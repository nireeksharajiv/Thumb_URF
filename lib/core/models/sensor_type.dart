/// Sensor positions and measurement sources used by the glove hardware.
enum SensorType {
  fsr('Thumb tip / distal phalanx', 'Thumb-tip pressure and force'),
  ipFlex('IP joint', 'IP joint bending angle'),
  mcpFlex('MCP joint', 'MCP joint bending angle'),
  mpu6050('Near the CMC joint', 'Motion, acceleration, and angular velocity');

  const SensorType(this.location, this.measurement);

  final String location;
  final String measurement;
}
