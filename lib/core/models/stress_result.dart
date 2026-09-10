/// Research-oriented loading result. Its score is supplied by a future calculator.
enum StressLevel {
  low('Low loading'),
  moderate('Moderate loading'),
  elevated('Elevated loading'),
  high('High loading');

  const StressLevel(this.label);

  final String label;
}

class StressResult {
  StressResult({
    required this.score,
    required this.level,
    required List<String> contributingFactors,
  }) : contributingFactors = List.unmodifiable(contributingFactors) {
    if (!score.isFinite || score < 0) {
      throw ArgumentError.value(
        score,
        'score',
        'Must be a finite non-negative value.',
      );
    }
  }

  final double score;
  final StressLevel level;
  final List<String> contributingFactors;

  Map<String, Object> toJson() => {
    'score': score,
    'level': level.name,
    'contributingFactors': contributingFactors,
  };
}
