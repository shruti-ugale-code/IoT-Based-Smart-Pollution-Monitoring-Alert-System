import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/aqi_data.dart';
import '../widgets/animated_gradient_background.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/aqi_line_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  List<AqiData> _historyData = [];
  bool _isLoading = true;
  int _selectedPeriod = 24; // hours
  late TabController _tabController;

  final List<Map<String, dynamic>> _periods = [
    {'label': '24H', 'hours': 24},
    {'label': '7D', 'hours': 168},
    {'label': '30D', 'hours': 720},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedPeriod = _periods[_tabController.index]['hours'] as int;
        });
        _loadHistory();
      }
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _historyData = AqiData.generateSampleHistory();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildPeriodTabs(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accentBlue,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: AppTheme.accentBlue,
                        backgroundColor: AppTheme.primaryMedium,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatsSummary(),
                              const SizedBox(height: 24),
                              _buildChart(),
                              const SizedBox(height: 24),
                              _buildDataTable(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history,
              color: AppTheme.accentBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Historical AQI data',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.download_outlined,
              color: AppTheme.textSecondary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Export feature coming soon'),
                  backgroundColor: AppTheme.primaryMedium,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.accentBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dividerColor: Colors.transparent,
        tabs: _periods.map((p) => Tab(text: p['label'] as String)).toList(),
      ),
    );
  }

  Widget _buildStatsSummary() {
    if (_historyData.isEmpty) return const SizedBox.shrink();

    final avgAqi = (_historyData.map((d) => d.aqi).reduce((a, b) => a + b) /
            _historyData.length)
        .round();
    final maxAqi =
        _historyData.map((d) => d.aqi).reduce((a, b) => a > b ? a : b);
    final minAqi =
        _historyData.map((d) => d.aqi).reduce((a, b) => a < b ? a : b);

    return Row(
      children: [
        Expanded(child: _buildStatCard('Average', '$avgAqi', AppTheme.getAqiColor(avgAqi))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Max', '$maxAqi', AppTheme.getAqiColor(maxAqi))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Min', '$minAqi', AppTheme.getAqiColor(minAqi))),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return GlassmorphicCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AQI',
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return GlassmorphicCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AQI Trend (Last ${_getPeriodLabel()})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.aqiGood.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.aqiGood,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AqiLineChart(
            data: _historyData,
            height: 220,
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 24:
        return '24 Hours';
      case 168:
        return '7 Days';
      case 720:
        return '30 Days';
      default:
        return '$_selectedPeriod Hours';
    }
  }

  Widget _buildDataTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Detailed Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 18),
              label: const Text('Filter'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassmorphicCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'AQI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'PM2.5',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'PM10',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              // Data Rows
              ...List.generate(
                _historyData.length > 10 ? 10 : _historyData.length,
                (index) {
                  final data = _historyData[index];
                  final aqiColor = AppTheme.getAqiColor(data.aqi);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.glassBorder.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatDateTime(data.timestamp),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: aqiColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${data.aqi}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: aqiColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            data.pm25.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            data.pm10.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Show More
              if (_historyData.length > 10)
                Container(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Show ${_historyData.length - 10} more entries',
                      style: const TextStyle(
                        color: AppTheme.accentBlue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime time) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${months[time.month - 1]} ${time.day}, $hour:$minute';
  }
}
