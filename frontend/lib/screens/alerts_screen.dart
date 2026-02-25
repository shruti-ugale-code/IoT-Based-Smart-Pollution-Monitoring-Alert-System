import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/alert.dart';
import '../widgets/animated_gradient_background.dart';
import '../widgets/glassmorphic_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  List<Alert> _alerts = [];
  bool _isLoading = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadAlerts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _alerts = Alert.sampleAlerts;
        _isLoading = false;
      });
    }
  }

  void _markAsRead(String alertId) {
    setState(() {
      final index = _alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        _alerts[index] = _alerts[index].copyWith(isRead: true);
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All alerts marked as read'),
        backgroundColor: AppTheme.primaryMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts.where((a) => !a.isRead).length;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(unreadCount),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accentBlue,
                        ),
                      )
                    : _alerts.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadAlerts,
                            color: AppTheme.accentBlue,
                            backgroundColor: AppTheme.primaryMedium,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _alerts.length,
                              itemBuilder: (context, index) {
                                return _buildAlertCard(_alerts[index], index);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Alerts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.aqiVeryUnhealthy.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount new',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.aqiVeryUnhealthy,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: AppTheme.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Alerts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Alert alert, int index) {
    final severityColor = Color(Alert.getSeverityColorValue(alert.severity));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key(alert.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.aqiVeryUnhealthy.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: AppTheme.aqiVeryUnhealthy,
          ),
        ),
        onDismissed: (direction) {
          setState(() {
            _alerts.removeWhere((a) => a.id == alert.id);
          });
        },
        child: GlassmorphicCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          onTap: () {
            if (!alert.isRead) _markAsRead(alert.id);
            _showAlertDetails(alert);
          },
          borderColor: !alert.isRead ? severityColor.withOpacity(0.5) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity Indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSeverityIcon(alert.severity),
                  color: severityColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  alert.isRead ? FontWeight.w500 : FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: severityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: alert.isRead
                            ? AppTheme.textMuted
                            : AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (alert.aqiValue != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.getAqiColor(alert.aqiValue!)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AQI ${alert.aqiValue}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.getAqiColor(alert.aqiValue!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _formatTime(alert.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Icons.info_outline;
      case AlertSeverity.medium:
        return Icons.warning_amber_rounded;
      case AlertSeverity.high:
        return Icons.error_outline;
      case AlertSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  void _showAlertDetails(Alert alert) {
    final severityColor = Color(Alert.getSeverityColorValue(alert.severity));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryMedium,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Severity Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSeverityIcon(alert.severity),
                    color: severityColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    alert.severity.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: severityColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              alert.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Message
            Text(
              alert.message,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // Details Row
            Row(
              children: [
                if (alert.aqiValue != null) ...[
                  _buildDetailChip(
                    Icons.speed,
                    'AQI ${alert.aqiValue}',
                    AppTheme.getAqiColor(alert.aqiValue!),
                  ),
                  const SizedBox(width: 12),
                ],
                if (alert.location != null)
                  _buildDetailChip(
                    Icons.location_on_outlined,
                    alert.location!,
                    AppTheme.accentBlue,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Timestamp
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatFullTime(alert.timestamp),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullTime(DateTime time) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${months[time.month - 1]} ${time.day}, ${time.year} at $hour:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
