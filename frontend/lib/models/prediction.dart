enum TrendDirection { up, down, stable }

class Prediction {
  final int predictedAqi;
  final double confidence;
  final DateTime timestamp;
  final TrendDirection trend;
  final String? description;
  final List<HourlyPrediction>? hourlyPredictions;

  Prediction({
    required this.predictedAqi,
    required this.confidence,
    required this.timestamp,
    required this.trend,
    this.description,
    this.hourlyPredictions,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      predictedAqi: json['predictedAqi'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      trend: _parseTrend(json['trend'] as String?),
      description: json['description'] as String?,
      hourlyPredictions: json['hourlyPredictions'] != null
          ? (json['hourlyPredictions'] as List)
              .map((e) => HourlyPrediction.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predictedAqi': predictedAqi,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'trend': trend.name,
      'description': description,
      'hourlyPredictions': hourlyPredictions?.map((e) => e.toJson()).toList(),
    };
  }

  static TrendDirection _parseTrend(String? value) {
    switch (value?.toLowerCase()) {
      case 'up':
        return TrendDirection.up;
      case 'down':
        return TrendDirection.down;
      case 'stable':
        return TrendDirection.stable;
      default:
        return TrendDirection.stable;
    }
  }

  String get trendIcon {
    switch (trend) {
      case TrendDirection.up:
        return '↑';
      case TrendDirection.down:
        return '↓';
      case TrendDirection.stable:
        return '→';
    }
  }

  String get trendText {
    switch (trend) {
      case TrendDirection.up:
        return 'Increasing';
      case TrendDirection.down:
        return 'Decreasing';
      case TrendDirection.stable:
        return 'Stable';
    }
  }

  // Get confidence as percentage string
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  // Sample prediction for testing
  static Prediction get samplePrediction => Prediction(
        predictedAqi: 95,
        confidence: 0.85,
        timestamp: DateTime.now().add(const Duration(hours: 6)),
        trend: TrendDirection.up,
        description: 'AQI expected to increase due to weather conditions',
        hourlyPredictions: List.generate(
          12,
          (index) => HourlyPrediction(
            hour: DateTime.now().add(Duration(hours: index + 1)).hour,
            predictedAqi: 85 + (index * 3) % 50,
            confidence: 0.9 - (index * 0.02),
          ),
        ),
      );
}

class HourlyPrediction {
  final int hour;
  final int predictedAqi;
  final double confidence;

  HourlyPrediction({
    required this.hour,
    required this.predictedAqi,
    required this.confidence,
  });

  factory HourlyPrediction.fromJson(Map<String, dynamic> json) {
    return HourlyPrediction(
      hour: json['hour'] as int? ?? 0,
      predictedAqi: json['predictedAqi'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'predictedAqi': predictedAqi,
      'confidence': confidence,
    };
  }
}
