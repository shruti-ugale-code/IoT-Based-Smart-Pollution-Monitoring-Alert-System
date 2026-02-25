import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';

class AqiGauge extends StatefulWidget {
  final int aqi;
  final double size;
  final Duration animationDuration;
  final bool showLabel;
  final bool animate;

  const AqiGauge({
    super.key,
    required this.aqi,
    this.size = 200,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.showLabel = true,
    this.animate = true,
  });

  @override
  State<AqiGauge> createState() => _AqiGaugeState();
}

class _AqiGaugeState extends State<AqiGauge>
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

    _animation = Tween<double>(begin: 0, end: widget.aqi.toDouble()).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AqiGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aqi != widget.aqi) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.aqi.toDouble(),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentAqi = _animation.value.toInt();
        final color = AppTheme.getAqiColor(currentAqi);
        final status = AppTheme.getAqiStatus(currentAqi);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: AqiGaugePainter(
                  progress: 1.0,
                  color: Colors.white.withOpacity(0.1),
                  strokeWidth: widget.size * 0.08,
                ),
              ),
              // Foreground arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: AqiGaugePainter(
                  progress: (currentAqi / 500).clamp(0.0, 1.0),
                  color: color,
                  strokeWidth: widget.size * 0.08,
                  hasGradient: true,
                ),
              ),
              // Glow effect
              Container(
                width: widget.size * 0.65,
                height: widget.size * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              // Inner content
              Container(
                width: widget.size * 0.6,
                height: widget.size * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryMedium.withOpacity(0.8),
                      AppTheme.primaryDark.withOpacity(0.9),
                    ],
                  ),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentAqi.toString(),
                      style: TextStyle(
                        fontSize: widget.size * 0.18,
                        fontWeight: FontWeight.bold,
                        color: color,
                        height: 1,
                      ),
                    ),
                    if (widget.showLabel) ...[
                      const SizedBox(height: 4),
                      Text(
                        'AQI',
                        style: TextStyle(
                          fontSize: widget.size * 0.06,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: widget.size * 0.055,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AqiGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool hasGradient;

  AqiGaugePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.hasGradient = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Start from bottom-left, sweep to bottom-right (270 degrees)
    const startAngle = 135 * math.pi / 180;
    const sweepAngle = 270 * math.pi / 180;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (hasGradient) {
      paint.shader = const SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          AppTheme.aqiGood,
          AppTheme.aqiModerate,
          AppTheme.aqiUnhealthy,
          AppTheme.aqiVeryUnhealthy,
        ],
        stops: [0.0, 0.33, 0.66, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      paint.color = color;
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(AqiGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
