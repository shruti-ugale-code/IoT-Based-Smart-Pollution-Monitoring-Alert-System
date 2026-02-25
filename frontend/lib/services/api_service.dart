import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/aqi_data.dart';
import '../models/alert.dart';
import '../models/prediction.dart';

const String baseUrl = "https://your-backend-url.onrender.com";

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class ApiService {
  final http.Client _client;
  final Duration _timeout = const Duration(seconds: 30);

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Headers for all requests
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // GET /current - Fetch current AQI data
  Future<AqiData> fetchCurrentAqi() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/current'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return AqiData.fromJson(json);
      } else {
        throw ApiException(
          'Failed to fetch current AQI',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException('Connection failed: $e');
    }
  }

  // GET /history - Fetch historical AQI data
  Future<List<AqiData>> fetchHistory({int? hours}) async {
    try {
      final queryParams = hours != null ? '?hours=$hours' : '';
      final response = await _client
          .get(
            Uri.parse('$baseUrl/history$queryParams'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body) as List;
        return jsonList
            .map((json) => AqiData.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch history',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException('Connection failed: $e');
    }
  }

  // GET /alerts - Fetch active alerts
  Future<List<Alert>> fetchAlerts() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/alerts'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body) as List;
        return jsonList
            .map((json) => Alert.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch alerts',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException('Connection failed: $e');
    }
  }

  // GET /prediction - Fetch AQI prediction
  Future<Prediction> fetchPrediction() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/prediction'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Prediction.fromJson(json);
      } else {
        throw ApiException(
          'Failed to fetch prediction',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException('Connection failed: $e');
    }
  }

  // POST /register-device - Register device for push notifications
  Future<bool> registerDevice(String token) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/register-device'),
            headers: _headers,
            body: jsonEncode({'token': token}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw ApiException(
          'Failed to register device',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException('Connection failed: $e');
    }
  }

  // Dispose client when done
  void dispose() {
    _client.close();
  }
}

// Singleton instance for global access
class ApiServiceProvider {
  static final ApiService _instance = ApiService();
  static ApiService get instance => _instance;
}
