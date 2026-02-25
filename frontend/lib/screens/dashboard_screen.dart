import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/aqi_data.dart';
import '../models/alert.dart';
import '../models/prediction.dart';
import '../widgets/animated_gradient_background.dart';
import '../widgets/aqi_gauge.dart';
import '../widgets/aqi_line_chart.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/trend_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  AqiData? _currentAqi;
  List<AqiData> _historyData = [];
  Prediction? _prediction;
  List<Alert> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Simulate API loading with sample data
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _currentAqi = AqiData.sampleData;
        _historyData = AqiData.generateSampleHistory();
        _prediction = Prediction.samplePrediction;
        _alerts = Alert.sampleAlerts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.accentBlue,
            backgroundColor: AppTheme.primaryMedium,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // App Bar
                _buildAppBar(),
                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // AQI Gauge Section
                      _buildAqiGaugeSection(),
                      const SizedBox(height: 24),
                      // Stats Grid
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      // Chart Section
                      _buildChartSection(),
                      const SizedBox(height: 100), // Bottom padding for nav bar
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.aqiGood.withOpacity(0.8),
                  AppTheme.accentBlue,
                ],
              ),
            ),
            child: const Icon(Icons.air_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AirWatch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _currentAqi?.location ?? 'Loading...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
              if (_alerts.where((a) => !a.isRead).isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.aqiVeryUnhealthy,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => Navigator.pushNamed(context, '/alerts'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAqiGaugeSection() {
    if (_isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.accentBlue),
        ),
      );
    }

    return Column(
      children: [
        Center(
          child: AqiGauge(
            aqi: _currentAqi?.aqi ?? 0,
            size: 220,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Last updated: ${_formatTime(_currentAqi?.timestamp ?? DateTime.now())}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoading) {
      return const SizedBox(height: 200);
    }

    final unreadAlerts = _alerts.where((a) => !a.isRead).length;
    final dailyAvg = _historyData.isEmpty
        ? 0
        : (_historyData.map((d) => d.aqi).reduce((a, b) => a + b) /
                _historyData.length)
            .round();

    // Calculate trend
    final trend = _historyData.length >= 2
        ? _historyData.last.aqi - _historyData[_historyData.length - 2].aqi
        : 0;
    final isPositive = trend <= 0; // Lower AQI is better

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TrendCard(
                title: 'Trend',
                value: '${trend.abs()}',
                subtitle: trend > 0 ? 'Rising' : 'Falling',
                isPositive: isPositive,
                icon: trend > 0 ? Icons.trending_up : Icons.trending_down,
                animationDelay: 100,
              ),
            ),
            Expanded(
              child: TrendCard(
                title: 'Daily Average',
                value: '$dailyAvg',
                subtitle: 'AQI',
                isPositive: dailyAvg < 100,
                icon: Icons.calendar_today,
                accentColor: AppTheme.getAqiColor(dailyAvg),
                animationDelay: 200,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TrendCard(
                title: 'Active Alerts',
                value: '$unreadAlerts',
                subtitle: 'Unread',
                isPositive: unreadAlerts == 0,
                icon: Icons.warning_amber_rounded,
                accentColor: unreadAlerts > 0
                    ? AppTheme.aqiUnhealthy
                    : AppTheme.aqiGood,
                animationDelay: 300,
                onTap: () => Navigator.pushNamed(context, '/alerts'),
              ),
            ),
            Expanded(
              child: TrendCard(
                title: 'Predicted AQI',
                value: '${_prediction?.predictedAqi ?? 0}',
                subtitle: _prediction?.trendText ?? '',
                isPositive: (_prediction?.trend ?? TrendDirection.stable) ==
                    TrendDirection.down,
                icon: Icons.auto_graph,
                accentColor:
                    AppTheme.getAqiColor(_prediction?.predictedAqi ?? 0),
                animationDelay: 400,
                onTap: () => Navigator.pushNamed(context, '/prediction'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '24-Hour Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/history'),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accentBlue),
                  ),
                )
              : AqiLineChart(
                  data: _historyData,
                  height: 200,
                ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
