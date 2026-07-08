import 'package:dose_wise/src/features/reminders/services/notification_action_background.dart';
import 'package:dose_wise/src/features/reminders/services/notification_action_handler.dart';
import 'package:dose_wise/src/features/reminders/services/reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// flutter_local_notifications-backed [ReminderService].
///
/// Never construct this in tests — it talks to platform channels. Tests
/// use [NoopReminderService] or a fake.
final class LocalNotificationReminderService implements ReminderService {
  LocalNotificationReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    this.onResponse,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// iOS caps pending notifications at 64; stay under it.
  static const int maxPending = 60;

  static const String _darwinCategory = 'doseActions';

  /// Invoked for responses delivered to the running app (a body tap that
  /// opened the app, or an iOS action tap while foregrounded). Background
  /// action taps go to [notificationActionBackground] instead.
  final void Function(String? actionId, String? payload)? onResponse;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'dose_reminders',
    'Dose reminders',
    channelDescription: 'Reminders for scheduled medication doses',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    actions: <AndroidNotificationAction>[
      // showsUserInterface: false → handled in the background isolate
      // without opening the app; the notification dismisses on tap.
      AndroidNotificationAction(
        NotificationActions.take,
        'Take',
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        NotificationActions.skip,
        'Skip',
        showsUserInterface: false,
      ),
    ],
  );

  static const DarwinNotificationDetails _darwinDetails =
      DarwinNotificationDetails(
    interruptionLevel: InterruptionLevel.timeSensitive,
    categoryIdentifier: _darwinCategory,
  );

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to the package default (UTC) if lookup fails.
    }

    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            _darwinCategory,
            actions: [
              DarwinNotificationAction.plain(
                NotificationActions.take,
                'Take',
              ),
              DarwinNotificationAction.plain(
                NotificationActions.skip,
                'Skip',
              ),
            ],
          ),
        ],
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) =>
          onResponse?.call(response.actionId, response.payload),
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
  }

  /// (actionId, payload) of the notification response that launched the
  /// app, if any — so an action tap that had to open the app still gets
  /// applied on startup.
  Future<(String?, String?)?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details == null || !details.didNotificationLaunchApp) return null;
    if (response == null) return null;
    return (response.actionId, response.payload);
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> scheduleAll(List<ReminderRequest> requests) async {
    await _plugin.cancelAll();
    final upcoming = [...requests]
      ..sort((a, b) => a.dose.time.compareTo(b.dose.time));

    for (final request in upcoming.take(maxPending)) {
      await _plugin.zonedSchedule(
        request.notificationId,
        request.title,
        request.body,
        tz.TZDateTime.from(request.dose.time, tz.local),
        const NotificationDetails(
          android: _androidDetails,
          iOS: _darwinDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationActionHandler.encodePayload(request.dose),
      );
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
