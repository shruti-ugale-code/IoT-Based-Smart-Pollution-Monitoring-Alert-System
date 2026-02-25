import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/aqi_data.dart';

class AqiLineChart extends StatefulWidget {
  final List<AqiData> data;
  final double height;
  final bool showGrid;
  final bool animate;
  final Duration animationDuration;

  const AqiLineChart({
    super.key,
    required this.data,
    this.height = 200,
    this.showGrid = true,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<AqiLineChart> createState() => _AqiLineChartState();
}

class _AqiLineChartState extends State<AqiLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              gridData: _buildGridData(),
              titlesData: _buildTitlesData(),
              borderData: FlBorderData(show: false),
              lineBarsData: [_buildLineChartBarData()],
              lineTouchData: _buildTouchData(),
              minX: 0,
              maxX: (widget.data.length - 1).toDouble(),
              minY: 0,
              maxY: _getMaxY(),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        );
      },
    );
  }

  double _getMaxY() {
    if (widget.data.isEmpty) return 100;
    final maxAqi = widget.data.map((d) => d.aqi).reduce((a, b) => a > b ? a : b);
    return (maxAqi * 1.2).ceilToDouble();
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: widget.showGrid,
      drawHorizontalLine: true,
      drawVerticalLine: false,
      horizontalInterval: 50,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: AppTheme.glassBorder.withOpacity(0.3),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: _getBottomInterval(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= widget.data.length) {
              return const SizedBox.shrink();
            }
            final hour = widget.data[index].timestamp.hour;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
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
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  double _getBottomInterval() {
    if (widget.data.length <= 6) return 1;
    if (widget.data.length <= 12) return 2;
    return 4;
  }

  LineChartBarData _buildLineChartBarData() {
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.data.length; i++) {
      final animatedAqi = widget.data[i].aqi * _animation.value;
      spots.add(FlSpot(i.toDouble(), animatedAqi));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: AppTheme.accentBlue,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final aqi = widget.data[index].aqi;
          final color = AppTheme.getAqiColor(aqi);
          return FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white.withOpacity(0.5),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.accentBlue.withOpacity(0.3 * _animation.value),
            AppTheme.accentBlue.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) => AppTheme.primaryMedium.withOpacity(0.9),
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final index = spot.x.toInt();
            if (index < 0 || index >= widget.data.length) return null;
            
            final data = widget.data[index];
            final color = AppTheme.getAqiColor(data.aqi);
            final time = '${data.timestamp.hour.toString().padLeft(2, '0')}:${data.timestamp.minute.toString().padLeft(2, '0')}';
            
            return LineTooltipItem(
              'AQI: ${data.aqi}\n$time',
              TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          }).toList();
        },
      ),
      touchSpotThreshold: 20,
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes.map((index) {
          return TouchedSpotIndicatorData(
            FlLine(
              color: AppTheme.accentBlue.withOpacity(0.5),
              strokeWidth: 2,
              dashArray: [4, 4],
            ),
            FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, idx) {
                final aqi = widget.data[index].aqi;
                return FlDotCirclePainter(
                  radius: 6,
                  color: AppTheme.getAqiColor(aqi),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
          );
        }).toList();
      },
    );
  }
}

// Mini sparkline chart for compact display
class AqiSparkline extends StatelessWidget {
  final List<int> data;
  final double height;
  final double width;
  final Color? color;

  const AqiSparkline({
    super.key,
    required this.data,
    this.height = 40,
    this.width = 100,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height, width: width);

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.toDouble());
    }).toList();

    final lineColor = color ?? AppTheme.accentBlue;

    return SizedBox(
      height: height,
      width: width,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withOpacity(0.3),
                    lineColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}
