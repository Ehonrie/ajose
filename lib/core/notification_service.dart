import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/circle.dart';

/// Thin wrapper around `flutter_local_notifications`. This phase just
/// proves the native plumbing (channel setup, Android 13+ runtime
/// permission) works; real "your round is due" scheduling against actual
/// on-chain round data comes with the Anchor program.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'ajose.round_reminders';
  static const _channelName = 'Round reminders';
  static const _channelDescription = 'Reminders that a circle contribution is due';

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidInit));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showRoundReminder(Circle circle) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      id: circle.id.hashCode,
      title: '${circle.name}: contribution due soon',
      body: '${circle.currentRecipient.displayName} receives this round\'s pot of '
          '\$${circle.potTotalUsdc.toStringAsFixed(0)} USDC.',
      notificationDetails: details,
    );
  }
}
