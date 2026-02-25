import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'alerts_screen.dart';
import 'prediction_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MapScreen(),
    const AlertsScreen(),
    const PredictionScreen(),
    const HistoryScreen(),
  ];

  final List<NavigationItem> _navItems = [
    NavigationItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    NavigationItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: 'Map',
    ),
    NavigationItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      label: 'Alerts',
    ),
    NavigationItem(
      icon: Icons.auto_graph_outlined,
      activeIcon: Icons.auto_graph,
      label: 'Predict',
    ),
    NavigationItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'History',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Current screen
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Custom Bottom Navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryMedium.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(
          _navItems.length,
          (index) => _buildNavItem(index),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentBlue.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.accentBlue : AppTheme.textMuted,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
