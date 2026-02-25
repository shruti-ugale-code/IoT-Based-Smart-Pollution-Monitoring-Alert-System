class AqiData {
  final int aqi;
  final double pm25;
  final double pm10;
  final double co;
  final double no2;
  final double o3;
  final DateTime timestamp;
  final String? location;

  AqiData({
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.o3,
    required this.timestamp,
    this.location,
  });

  factory AqiData.fromJson(Map<String, dynamic> json) {
    return AqiData(
      aqi: json['aqi'] as int? ?? 0,
      pm25: (json['pm25'] as num?)?.toDouble() ?? 0.0,
      pm10: (json['pm10'] as num?)?.toDouble() ?? 0.0,
      co: (json['co'] as num?)?.toDouble() ?? 0.0,
      no2: (json['no2'] as num?)?.toDouble() ?? 0.0,
      o3: (json['o3'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aqi': aqi,
      'pm25': pm25,
      'pm10': pm10,
      'co': co,
      'no2': no2,
      'o3': o3,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
    };
  }

  // Copy with method for immutability
  AqiData copyWith({
    int? aqi,
    double? pm25,
    double? pm10,
    double? co,
    double? no2,
    double? o3,
    DateTime? timestamp,
    String? location,
  }) {
    return AqiData(
      aqi: aqi ?? this.aqi,
      pm25: pm25 ?? this.pm25,
      pm10: pm10 ?? this.pm10,
      co: co ?? this.co,
      no2: no2 ?? this.no2,
      o3: o3 ?? this.o3,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
    );
  }

  // Sample data for testing
  static AqiData get sampleData => AqiData(
        aqi: 85,
        pm25: 35.5,
        pm10: 68.2,
        co: 1.2,
        no2: 25.4,
        o3: 45.8,
        timestamp: DateTime.now(),
        location: 'Pune, India',
      );

  // Generate sample history data
  static List<AqiData> generateSampleHistory() {
    final now = DateTime.now();
    return List.generate(24, (index) {
      return AqiData(
        aqi: 50 + (index * 5) % 100,
        pm25: 20.0 + (index * 2) % 50,
        pm10: 40.0 + (index * 3) % 80,
        co: 0.5 + (index * 0.1) % 2,
        no2: 15.0 + (index * 1.5) % 40,
        o3: 30.0 + (index * 2) % 60,
        timestamp: now.subtract(Duration(hours: 23 - index)),
        location: 'Pune, India',
      );
    });
  }
}

class HourlyAqiData {
  final int hour;
  final int aqi;

  HourlyAqiData({required this.hour, required this.aqi});

  factory HourlyAqiData.fromJson(Map<String, dynamic> json) {
    return HourlyAqiData(
      hour: json['hour'] as int? ?? 0,
      aqi: json['aqi'] as int? ?? 0,
    );
  }
}
