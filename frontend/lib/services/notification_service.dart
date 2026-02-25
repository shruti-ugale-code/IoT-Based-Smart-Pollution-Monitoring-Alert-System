import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'api_service.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pollution_alerts_channel',
    'Pollution Alerts',
    description: 'Notifications for air quality alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // Callback for handling notification taps
  Function(RemoteMessage)? onNotificationTap;
  
  // Callback for showing in-app dialog
  Function(RemoteMessage)? onShowInAppDialog;

  // Initialize the notification service
  Future<void> initialize() async {
    // Initialize local notifications
    await _initializeLocalNotifications();

    // Request permissions
    await _requestPermissions();

    // Setup message handlers
    _setupMessageHandlers();

    // Get and register device token
    await _registerDeviceToken();
  }

  // Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('Notification permission status: ${settings.authorizationStatus}');
  }

  // Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background/terminated message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle initial message when app opens from terminated state
    _handleInitialMessage();
  }

  // Handle messages when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message received: ${message.notification?.title}');

    // Show local notification
    await _showLocalNotification(message);

    // Vibrate device
    await _vibrateDevice();

    // Show in-app dialog if callback is set
    onShowInAppDialog?.call(message);
  }

  // Handle when user taps notification (app in background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.notification?.title}');
    onNotificationTap?.call(message);
  }

  // Handle initial message when app opens from terminated state
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('Initial message: ${initialMessage.notification?.title}');
      onNotificationTap?.call(initialMessage);
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'pollution_alerts_channel',
      'Pollution Alerts',
      channelDescription: 'Notifications for air quality alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: ui.Color(0xFFF44336),
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? '',
      body: notification.body ?? '',
      notificationDetails: details,
      payload: message.data.toString(),
    );
  }

  // Handle notification tap from local notifications
  void _onNotificationResponse(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    // Handle notification tap navigation here
  }

  // Vibrate device
  Future<void> _vibrateDevice() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 500, amplitude: 128);
    }
  }

  // Get and register device token
  Future<void> _registerDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _sendTokenToServer(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  // Send token to backend server
  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiServiceProvider.instance.registerDevice(token);
      print('Device token registered successfully');
    } catch (e) {
      print('Error registering device token: $e');
    }
  }

  // Get current FCM token
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  // Show a custom local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pollution_alerts_channel',
      'Pollution Alerts',
      channelDescription: 'Notifications for air quality alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
