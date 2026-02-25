import 'package:flutter/material.dart';
import '../config/theme.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final Duration duration;
  final bool animate;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.duration = const Duration(seconds: 10),
    this.animate = true,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final List<List<Color>> _gradients = [
    [
      AppTheme.gradientStart,
      AppTheme.gradientMiddle,
      AppTheme.gradientEnd,
    ],
    [
      const Color(0xFF0D1B2A),
      const Color(0xFF1B263B),
      const Color(0xFF3D2C5E),
    ],
    [
      const Color(0xFF0F1923),
      const Color(0xFF1D2B3A),
      const Color(0xFF2D1B4E),
    ],
    [
      const Color(0xFF0D1B2A),
      const Color(0xFF1B263B),
      const Color(0xFF2D1B4E),
    ],
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.animate) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _gradients.length;
          });
          _controller.reset();
          _controller.forward();
        }
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _lerpColors(List<Color> from, List<Color> to, double t) {
    return List.generate(
      from.length,
      (index) => Color.lerp(from[index], to[index], t)!,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.colors != null || !widget.animate) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.colors ?? _gradients[0],
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final nextIndex = (_currentIndex + 1) % _gradients.length;
        final colors = _lerpColors(
          _gradients[_currentIndex],
          _gradients[nextIndex],
          _animation.value,
        );

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

// Simple static gradient background
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: colors ??
              [
                AppTheme.gradientStart,
                AppTheme.gradientMiddle,
                AppTheme.gradientEnd,
              ],
        ),
      ),
      child: child,
    );
  }
}

// Animated mesh gradient for more dynamic effects
class MeshGradientBackground extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const MeshGradientBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                -0.5 + _controller.value,
                -0.5 + _controller.value * 0.5,
              ),
              radius: 1.5,
              colors: [
                AppTheme.gradientEnd.withOpacity(0.8),
                AppTheme.gradientMiddle,
                AppTheme.gradientStart,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(
                  0.5 - _controller.value * 0.5,
                  0.5 - _controller.value,
                ),
                radius: 1.0,
                colors: [
                  const Color(0xFF4A1B6B).withOpacity(0.3 * _controller.value),
                  Colors.transparent,
                ],
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
