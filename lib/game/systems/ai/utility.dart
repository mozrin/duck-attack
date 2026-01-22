class Utility {
  static const double wDist = 1.0;
  static const double wAggression = 1.0;
  static const double wSwarm = 0.5;

  static const double wLureDist = 2.0;
  static const double wLureFreshness = 1.0;
  static const double wLureTime = 1.0;
  static const double wLureCrowding = 1.5;

  static double benchUtility({
    required double distanceToBench,
    required double aggression,
    required double swarmFactor,
  }) {
    // Avoid division by zero
    final distScore = distanceToBench > 0 ? 1000 / distanceToBench : 1000.0;
    return (wDist * distScore) +
        (wAggression * aggression) +
        (wSwarm * swarmFactor);
  }

  static double lureUtility({
    required double distanceToLure,
    required double freshness,
    required double timeRemaining,
    required double crowding,
  }) {
    final distScore = distanceToLure > 0 ? 1000 / distanceToLure : 1000.0;
    return (wLureDist * distScore) +
        (wLureFreshness * freshness) +
        (wLureTime * timeRemaining) -
        (wLureCrowding * crowding);
  }
}
