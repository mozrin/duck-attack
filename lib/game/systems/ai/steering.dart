import 'package:flame/components.dart';

class Steering {
  static Vector2 seek(Vector2 currentPos, Vector2 targetPos, double maxSpeed) {
    if (currentPos == targetPos) return Vector2.zero();
    final desired = (targetPos - currentPos).normalized() * maxSpeed;
    return desired; // In a full physics system, this would be a force. Here we return velocity for simplicity first.
  }

  static Vector2 flee(Vector2 currentPos, Vector2 targetPos, double maxSpeed) {
    if (currentPos == targetPos) return Vector2.zero();
    final desired = (currentPos - targetPos).normalized() * maxSpeed;
    return desired;
  }

  static Vector2 arrive(
    Vector2 currentPos,
    Vector2 targetPos,
    double maxSpeed,
    double slowingRadius,
  ) {
    final toTarget = targetPos - currentPos;
    final dist = toTarget.length;
    if (dist < 0.01) return Vector2.zero();

    double speed = maxSpeed;
    if (dist < slowingRadius) {
      speed = maxSpeed * (dist / slowingRadius);
    }

    return toTarget.normalized() * speed;
  }
}
