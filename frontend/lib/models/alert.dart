enum AlertSeverity { low, medium, high, critical }

class Alert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final bool isRead;
  final int? aqiValue;
  final String? location;

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isRead = false,
    this.aqiValue,
    this.location,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Alert',
      message: json['message'] as String? ?? '',
      severity: _parseSeverity(json['severity'] as String?),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      aqiValue: json['aqiValue'] as int?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'aqiValue': aqiValue,
      'location': location,
    };
  }

  static AlertSeverity _parseSeverity(String? value) {
    switch (value?.toLowerCase()) {
      case 'low':
        return AlertSeverity.low;
      case 'medium':
        return AlertSeverity.medium;
      case 'high':
        return AlertSeverity.high;
      case 'critical':
        return AlertSeverity.critical;
      default:
        return AlertSeverity.medium;
    }
  }

  Alert copyWith({
    String? id,
    String? title,
    String? message,
    AlertSeverity? severity,
    DateTime? timestamp,
    bool? isRead,
    int? aqiValue,
    String? location,
  }) {
    return Alert(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      aqiValue: aqiValue ?? this.aqiValue,
      location: location ?? this.location,
    );
  }

  // Get color based on severity
  static int getSeverityColorValue(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return 0xFF4CAF50; // Green
      case AlertSeverity.medium:
        return 0xFFFFEB3B; // Yellow
      case AlertSeverity.high:
        return 0xFFFF9800; // Orange
      case AlertSeverity.critical:
        return 0xFFF44336; // Red
    }
  }

  // Sample alerts for testing
  static List<Alert> get sampleAlerts => [
        Alert(
          id: '1',
          title: 'High AQI Alert',
          message: 'AQI has exceeded 150. Consider staying indoors.',
          severity: AlertSeverity.high,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          aqiValue: 165,
          location: 'Pune, India',
        ),
        Alert(
          id: '2',
          title: 'Air Quality Warning',
          message: 'PM2.5 levels are rising. Sensitive groups should take precautions.',
          severity: AlertSeverity.medium,
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          aqiValue: 95,
          location: 'Pune, India',
        ),
        Alert(
          id: '3',
          title: 'Critical Pollution Level',
          message: 'AQI has reached hazardous levels. Avoid outdoor activities.',
          severity: AlertSeverity.critical,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          aqiValue: 250,
          location: 'Pune, India',
          isRead: true,
        ),
        Alert(
          id: '4',
          title: 'Improving Air Quality',
          message: 'AQI has dropped to moderate levels.',
          severity: AlertSeverity.low,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          aqiValue: 55,
          location: 'Pune, India',
          isRead: true,
        ),
      ];
}
