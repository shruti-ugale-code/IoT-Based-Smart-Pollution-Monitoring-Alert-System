import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/prediction.dart';
import '../widgets/animated_gradient_background.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/aqi_gauge.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  Prediction? _prediction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  Future<void> _loadPrediction() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _prediction = Prediction.samplePrediction;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                )
              : RefreshIndicator(
                  onRefresh: _loadPrediction,
                  color: AppTheme.accentBlue,
                  backgroundColor: AppTheme.primaryMedium,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildPredictedAqiCard(),
                        const SizedBox(height: 16),
                        _buildConfidenceCard(),
                        const SizedBox(height: 16),
                        _buildTrendCard(),
                        const SizedBox(height: 24),
                        _buildHourlyPredictionChart(),
                        const SizedBox(height: 24),
                        _buildRecommendations(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_graph,
            color: AppTheme.accentBlue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Prediction',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'ML-powered forecast',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPredictedAqiCard() {
    if (_prediction == null) return const SizedBox.shrink();

    final aqiColor = AppTheme.getAqiColor(_prediction!.predictedAqi);
    final status = AppTheme.getAqiStatus(_prediction!.predictedAqi);

    return GlassmorphicCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule,
                color: AppTheme.textMuted,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Next 6 Hours',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AqiGauge(
            aqi: _prediction!.predictedAqi,
            size: 180,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: aqiColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: aqiColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _prediction!.trend == TrendDirection.up
                      ? Icons.trending_up
                      : _prediction!.trend == TrendDirection.down
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  color: aqiColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$status - ${_prediction!.trendText}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: aqiColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard() {
    if (_prediction == null) return const SizedBox.shrink();

    final confidence = _prediction!.confidence;
    final confidenceColor = confidence > 0.8
        ? AppTheme.aqiGood
        : confidence > 0.6
            ? AppTheme.aqiModerate
            : AppTheme.aqiUnhealthy;

    return GlassmorphicCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Model Confidence',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                _prediction!.confidencePercentage,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: confidenceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: AppTheme.glassBorder,
              valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            confidence > 0.8
                ? 'High confidence prediction'
                : confidence > 0.6
                    ? 'Moderate confidence prediction'
                    : 'Low confidence - conditions may change',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    if (_prediction == null) return const SizedBox.shrink();

    return GlassmorphicCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analysis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppTheme.aqiModerate,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _prediction!.description ??
                      'AQI is expected to ${_prediction!.trendText.toLowerCase()} in the coming hours.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyPredictionChart() {
    if (_prediction?.hourlyPredictions == null ||
        _prediction!.hourlyPredictions!.isEmpty) {
      return const SizedBox.shrink();
    }

    final predictions = _prediction!.hourlyPredictions!;

    return GlassmorphicCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hourly Forecast',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 200,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppTheme.primaryMedium,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final pred = predictions[groupIndex];
                      return BarTooltipItem(
                        'AQI: ${pred.predictedAqi}\n${pred.hour}:00',
                        TextStyle(
                          color: AppTheme.getAqiColor(pred.predictedAqi),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= predictions.length) {
                          return const SizedBox.shrink();
                        }
                        if (index % 2 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${predictions[index].hour}h',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.glassBorder.withOpacity(0.3),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                  drawVerticalLine: false,
                ),
                barGroups: List.generate(predictions.length, (index) {
                  final pred = predictions[index];
                  final color = AppTheme.getAqiColor(pred.predictedAqi);
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: pred.predictedAqi.toDouble(),
                        color: color,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 200,
                          color: AppTheme.glassWhite,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_prediction == null) return const SizedBox.shrink();

    final aqi = _prediction!.predictedAqi;
    final recommendations = _getRecommendations(aqi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommendations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...recommendations.map((rec) => _buildRecommendationItem(rec)),
      ],
    );
  }

  List<Map<String, dynamic>> _getRecommendations(int aqi) {
    if (aqi <= 50) {
      return [
        {'icon': Icons.directions_run, 'text': 'Great day for outdoor activities'},
        {'icon': Icons.window, 'text': 'Good time to ventilate your home'},
        {'icon': Icons.nature_people, 'text': 'Perfect for exercising outdoors'},
      ];
    } else if (aqi <= 100) {
      return [
        {'icon': Icons.directions_walk, 'text': 'Outdoor activities are generally fine'},
        {'icon': Icons.elderly, 'text': 'Sensitive groups should limit prolonged outdoor exertion'},
        {'icon': Icons.masks, 'text': 'Consider wearing a mask if sensitive to pollution'},
      ];
    } else if (aqi <= 200) {
      return [
        {'icon': Icons.home, 'text': 'Reduce prolonged outdoor activities'},
        {'icon': Icons.masks, 'text': 'Wear N95 mask outdoors'},
        {'icon': Icons.air, 'text': 'Use air purifiers indoors'},
        {'icon': Icons.window_outlined, 'text': 'Keep windows closed'},
      ];
    } else {
      return [
        {'icon': Icons.warning, 'text': 'Avoid all outdoor activities'},
        {'icon': Icons.home, 'text': 'Stay indoors as much as possible'},
        {'icon': Icons.masks, 'text': 'Use N95/N99 mask if going outside'},
        {'icon': Icons.air, 'text': 'Run air purifiers continuously'},
        {'icon': Icons.local_hospital, 'text': 'Seek medical help if experiencing symptoms'},
      ];
    }
  }

  Widget _buildRecommendationItem(Map<String, dynamic> rec) {
    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            rec['icon'] as IconData,
            color: AppTheme.accentBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rec['text'] as String,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
